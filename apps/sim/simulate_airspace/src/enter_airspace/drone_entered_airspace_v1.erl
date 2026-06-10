%%% @doc Event `drone_entered_airspace_v1`. Ground truth: a drone appeared.
-module(drone_entered_airspace_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_drone_id/1, get_drone_type/1, get_remote_id/1,
         get_x/1, get_y/1, get_alt/1, get_entered_at/1]).

-record(drone_entered_airspace_v1, {
    drone_id   :: binary() | undefined,
    drone_type :: binary() | undefined,
    remote_id  :: present | absent | undefined,
    x          :: number() | undefined,
    y          :: number() | undefined,
    alt        :: number() | undefined,
    entered_at :: integer() | undefined
}).

-type t() :: #drone_entered_airspace_v1{}.
-export_type([t/0]).

event_type() -> drone_entered_airspace_v1.

-spec new(map()) -> {ok, t()}.
new(#{drone_id := Id} = P) ->
    {ok, #drone_entered_airspace_v1{
        drone_id   = Id,
        drone_type = maps:get(drone_type, P, undefined),
        remote_id  = maps:get(remote_id, P, absent),
        x          = maps:get(x, P, undefined),
        y          = maps:get(y, P, undefined),
        alt        = maps:get(alt, P, undefined),
        entered_at = maps:get(entered_at, P, erlang:system_time(millisecond))}}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"drone_id">> := Id} = M) ->
    new(#{drone_id => Id,
          drone_type => maps:get(<<"drone_type">>, M, undefined),
          remote_id  => maps:get(<<"remote_id">>, M, absent),
          x => maps:get(<<"x">>, M, undefined),
          y => maps:get(<<"y">>, M, undefined),
          alt => maps:get(<<"alt">>, M, undefined),
          entered_at => maps:get(<<"entered_at">>, M, undefined)});
from_map(#{drone_id := _} = M) ->
    new(M).

-spec to_map(t()) -> map().
to_map(#drone_entered_airspace_v1{} = E) ->
    #{event_type => <<"drone_entered_airspace">>,
      drone_id   => E#drone_entered_airspace_v1.drone_id,
      drone_type => E#drone_entered_airspace_v1.drone_type,
      remote_id  => E#drone_entered_airspace_v1.remote_id,
      x          => E#drone_entered_airspace_v1.x,
      y          => E#drone_entered_airspace_v1.y,
      alt        => E#drone_entered_airspace_v1.alt,
      entered_at => E#drone_entered_airspace_v1.entered_at}.

get_drone_id(#drone_entered_airspace_v1{drone_id = V})     -> V.
get_drone_type(#drone_entered_airspace_v1{drone_type = V}) -> V.
get_remote_id(#drone_entered_airspace_v1{remote_id = V})   -> V.
get_x(#drone_entered_airspace_v1{x = V})                   -> V.
get_y(#drone_entered_airspace_v1{y = V})                   -> V.
get_alt(#drone_entered_airspace_v1{alt = V})               -> V.
get_entered_at(#drone_entered_airspace_v1{entered_at = V}) -> V.
