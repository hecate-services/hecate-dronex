%%% @doc Integration fact `airspace.track_confirmed`.
%%%
%%% Fusion's escalation-grade output: a correlated, confirmed airspace track.
%%% Published by dronex-edge (fuse_airspace); consumed by alerting, peer sites,
%%% and (in the simulator) the scoring oracle.
-module(airspace_track_confirmed).

-export([fact_name/0, version/0, topic/1]).
-export([new/1]).
-export([track_id/1, drone/1, position/1, confidence/1, sensor_ids/1,
         first_seen_at/1, confirmed_at/1]).

-spec fact_name() -> binary().
fact_name() -> <<"airspace.track_confirmed">>.

-spec version() -> pos_integer().
version() -> 1.

-spec topic(binary() | string()) -> binary().
topic(Site) when is_list(Site)   -> topic(list_to_binary(Site));
topic(Site) when is_binary(Site) -> <<"airspace/", Site/binary, "/track_confirmed">>.

-spec new(map()) -> map().
new(P) ->
    #{fact          => fact_name(),
      v             => version(),
      track_id      => maps:get(track_id, P),
      drone         => maps:get(drone, P, #{}),
      position      => maps:get(position, P, undefined),
      confidence    => maps:get(confidence, P, 0.0),
      sensor_ids    => maps:get(sensor_ids, P, []),
      first_seen_at => maps:get(first_seen_at, P, undefined),
      confirmed_at  => maps:get(confirmed_at, P, erlang:system_time(millisecond))}.

track_id(F)      -> get(track_id, F).
drone(F)         -> get(drone, F, #{}).
position(F)      -> get(position, F).
confidence(F)    -> get(confidence, F, 0.0).
sensor_ids(F)    -> get(sensor_ids, F, []).
first_seen_at(F) -> get(first_seen_at, F).
confirmed_at(F)  -> get(confirmed_at, F).

%%--------------------------------------------------------------------

%% ⚠ FLATTENED. See the same note in `airspace_contact_observed': the org's
%% `no_deep_nesting' limit of 2 now applies to every module under `apps/*/src',
%% and the counter-UAS line's rebar.config carried no elvis block at all, so
%% these two modules had never been linted.
get(Key, Map) -> get(Key, Map, undefined).

get(Key, Map, Default) -> found(maps:find(Key, Map), Key, Map, Default).

found({ok, V}, _Key, _Map, _Default) -> V;
found(error, Key, Map, Default) -> as_text(maps:find(atom_to_binary(Key, utf8), Map), Default).

as_text({ok, V}, _Default) -> V;
as_text(error, Default) -> Default.
