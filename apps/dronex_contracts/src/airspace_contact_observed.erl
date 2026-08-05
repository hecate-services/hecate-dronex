%%% @doc Integration fact `airspace.contact_observed`.
%%%
%%% THE contract at the swap point. A simulated sensor and a real sensor both
%%% produce exactly this map and publish it on this topic. Fusion consumes it
%%% and cannot tell which produced it.
%%%
%%% Accessors tolerate atom OR binary keys: a fact built in-process carries
%%% atom keys; one round-tripped through the CBOR mesh wire may arrive with
%%% text keys.
-module(airspace_contact_observed).

-export([fact_name/0, version/0, topic/1]).
-export([new/1]).
-export([sensor_id/1, modality/1, observed_at/1, position/1, bearing_deg/1,
         range_m/1, drone/1, confidence/1]).

-spec fact_name() -> binary().
fact_name() -> <<"airspace.contact_observed">>.

-spec version() -> pos_integer().
version() -> 1.

%% @doc Pub/sub topic for a site. Real and simulated sensors publish here.
-spec topic(binary() | string()) -> binary().
topic(Site) when is_list(Site)   -> topic(list_to_binary(Site));
topic(Site) when is_binary(Site) -> <<"airspace/", Site/binary, "/contact_observed">>.

%% @doc Build a fact from a params map. position is #{x,y} (and optional alt)
%% in site-local metres; bearing_deg/range_m are optional (sensor-dependent).
-spec new(map()) -> map().
new(P) ->
    #{fact        => fact_name(),
      v           => version(),
      sensor_id   => maps:get(sensor_id, P),
      modality    => maps:get(modality, P),
      observed_at => maps:get(observed_at, P, erlang:system_time(millisecond)),
      position    => maps:get(position, P, undefined),
      bearing_deg => maps:get(bearing_deg, P, undefined),
      range_m     => maps:get(range_m, P, undefined),
      drone       => maps:get(drone, P, #{}),
      confidence  => maps:get(confidence, P, 0.0)}.

sensor_id(F)   -> get(sensor_id, F).
modality(F)    -> get(modality, F).
observed_at(F) -> get(observed_at, F).
position(F)    -> get(position, F).
bearing_deg(F) -> get(bearing_deg, F).
range_m(F)     -> get(range_m, F).
drone(F)       -> get(drone, F, #{}).
confidence(F)  -> get(confidence, F, 0.0).

%%--------------------------------------------------------------------

%% ⚠ FLATTENED, AND THE NESTING WAS NOT MERELY UNTIDY. Two `case' expressions
%% inside each other put this over the org's `no_deep_nesting' limit of 2, which
%% this repository's rebar.config applies to every module under `apps/*/src' and
%% the counter-UAS line's rebar.config did not apply at all. Clauses say the same
%% thing with the fallback visible on its own line.
get(Key, Map) -> get(Key, Map, undefined).

get(Key, Map, Default) -> found(maps:find(Key, Map), Key, Map, Default).

found({ok, V}, _Key, _Map, _Default) -> V;
found(error, Key, Map, Default) -> as_text(maps:find(atom_to_binary(Key, utf8), Map), Default).

as_text({ok, V}, _Default) -> V;
as_text(error, Default) -> Default.
