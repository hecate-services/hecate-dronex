%%% @doc Event `drone_departed_v1`. Ground truth: the drone left the airspace.
-module(drone_departed_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_drone_id/1, get_departed_at/1]).

-record(drone_departed_v1, {
    drone_id    :: binary() | undefined,
    departed_at :: integer() | undefined
}).

-opaque t() :: #drone_departed_v1{}.
-export_type([t/0]).

event_type() -> drone_departed_v1.

-spec new(map()) -> {ok, t()}.
new(#{drone_id := Id} = P) ->
    {ok, #drone_departed_v1{
        drone_id    = Id,
        departed_at = maps:get(departed_at, P, erlang:system_time(millisecond))}}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"drone_id">> := Id} = M) ->
    new(#{drone_id => Id, departed_at => maps:get(<<"departed_at">>, M, undefined)});
from_map(#{drone_id := _} = M) -> new(M).

-spec to_map(t()) -> map().
to_map(#drone_departed_v1{} = E) ->
    #{event_type  => <<"drone_departed">>,
      drone_id    => E#drone_departed_v1.drone_id,
      departed_at => E#drone_departed_v1.departed_at}.

get_drone_id(#drone_departed_v1{drone_id = V})       -> V.
get_departed_at(#drone_departed_v1{departed_at = V}) -> V.
