%%% @doc Event `drone_repositioned_v1`. Ground truth: the drone's new position.
%%% This is the event the sensor emitter (observe_remote_id) reacts to, and the
%%% one the scorer projects into its ground-truth table.
-module(drone_repositioned_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_drone_id/1, get_x/1, get_y/1, get_alt/1, get_observed_at/1]).

-record(drone_repositioned_v1, {
    drone_id    :: binary() | undefined,
    x           :: number() | undefined,
    y           :: number() | undefined,
    alt         :: number() | undefined,
    observed_at :: integer() | undefined
}).

-type t() :: #drone_repositioned_v1{}.
-export_type([t/0]).

event_type() -> drone_repositioned_v1.

-spec new(map()) -> {ok, t()}.
new(#{drone_id := Id} = P) ->
    {ok, #drone_repositioned_v1{
        drone_id    = Id,
        x           = maps:get(x, P, undefined),
        y           = maps:get(y, P, undefined),
        alt         = maps:get(alt, P, undefined),
        observed_at = maps:get(observed_at, P, erlang:system_time(millisecond))}}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"drone_id">> := Id} = M) ->
    new(#{drone_id => Id,
          x => maps:get(<<"x">>, M, undefined),
          y => maps:get(<<"y">>, M, undefined),
          alt => maps:get(<<"alt">>, M, undefined),
          observed_at => maps:get(<<"observed_at">>, M, undefined)});
from_map(#{drone_id := _} = M) -> new(M).

-spec to_map(t()) -> map().
to_map(#drone_repositioned_v1{} = E) ->
    #{event_type  => <<"drone_repositioned">>,
      drone_id    => E#drone_repositioned_v1.drone_id,
      x           => E#drone_repositioned_v1.x,
      y           => E#drone_repositioned_v1.y,
      alt         => E#drone_repositioned_v1.alt,
      observed_at => E#drone_repositioned_v1.observed_at}.

get_drone_id(#drone_repositioned_v1{drone_id = V})       -> V.
get_x(#drone_repositioned_v1{x = V})                     -> V.
get_y(#drone_repositioned_v1{y = V})                     -> V.
get_alt(#drone_repositioned_v1{alt = V})                 -> V.
get_observed_at(#drone_repositioned_v1{observed_at = V}) -> V.
