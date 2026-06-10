%%% @doc Event `track_confirmed_v1` (edge DOMAIN event, in the local store).
%%%
%%% Not to be confused with the `airspace.track_confirmed` integration FACT
%%% (airspace_track_confirmed): this is the internal record of the decision;
%%% the correlator separately publishes the public fact to the mesh.
-module(track_confirmed_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_track_id/1, get_drone/1, get_x/1, get_y/1, get_alt/1,
         get_confidence/1, get_sensor_ids/1, get_first_seen_at/1, get_confirmed_at/1]).

-record(track_confirmed_v1, {
    track_id      :: binary() | undefined,
    drone         :: map() | undefined,
    x             :: number() | undefined,
    y             :: number() | undefined,
    alt           :: number() | undefined,
    confidence    :: float() | undefined,
    sensor_ids    :: [binary()] | undefined,
    first_seen_at :: integer() | undefined,
    confirmed_at  :: integer() | undefined
}).

-opaque t() :: #track_confirmed_v1{}.
-export_type([t/0]).

event_type() -> track_confirmed_v1.

-spec new(map()) -> {ok, t()}.
new(#{track_id := Id} = P) ->
    {ok, #track_confirmed_v1{
        track_id      = Id,
        drone         = maps:get(drone, P, #{}),
        x             = maps:get(x, P, undefined),
        y             = maps:get(y, P, undefined),
        alt           = maps:get(alt, P, undefined),
        confidence    = maps:get(confidence, P, 0.0),
        sensor_ids    = maps:get(sensor_ids, P, []),
        first_seen_at = maps:get(first_seen_at, P, undefined),
        confirmed_at  = maps:get(confirmed_at, P, erlang:system_time(millisecond))}}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"track_id">> := Id} = M) ->
    new(#{track_id => Id,
          drone => maps:get(<<"drone">>, M, #{}),
          x => maps:get(<<"x">>, M, undefined),
          y => maps:get(<<"y">>, M, undefined),
          alt => maps:get(<<"alt">>, M, undefined),
          confidence => maps:get(<<"confidence">>, M, 0.0),
          sensor_ids => maps:get(<<"sensor_ids">>, M, []),
          first_seen_at => maps:get(<<"first_seen_at">>, M, undefined),
          confirmed_at => maps:get(<<"confirmed_at">>, M, undefined)});
from_map(#{track_id := _} = M) -> new(M).

-spec to_map(t()) -> map().
to_map(#track_confirmed_v1{} = E) ->
    #{event_type    => <<"track_confirmed">>,
      track_id      => E#track_confirmed_v1.track_id,
      drone         => E#track_confirmed_v1.drone,
      x             => E#track_confirmed_v1.x,
      y             => E#track_confirmed_v1.y,
      alt           => E#track_confirmed_v1.alt,
      confidence    => E#track_confirmed_v1.confidence,
      sensor_ids    => E#track_confirmed_v1.sensor_ids,
      first_seen_at => E#track_confirmed_v1.first_seen_at,
      confirmed_at  => E#track_confirmed_v1.confirmed_at}.

get_track_id(#track_confirmed_v1{track_id = V})           -> V.
get_drone(#track_confirmed_v1{drone = V})                 -> V.
get_x(#track_confirmed_v1{x = V})                         -> V.
get_y(#track_confirmed_v1{y = V})                         -> V.
get_alt(#track_confirmed_v1{alt = V})                     -> V.
get_confidence(#track_confirmed_v1{confidence = V})       -> V.
get_sensor_ids(#track_confirmed_v1{sensor_ids = V})       -> V.
get_first_seen_at(#track_confirmed_v1{first_seen_at = V}) -> V.
get_confirmed_at(#track_confirmed_v1{confirmed_at = V})   -> V.
