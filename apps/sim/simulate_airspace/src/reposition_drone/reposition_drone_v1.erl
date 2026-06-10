%%% @doc Command `reposition_drone_v1`. The drone moved to a new position.
-module(reposition_drone_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1, stream_id/1]).
-export([get_drone_id/1, get_x/1, get_y/1, get_alt/1, get_observed_at/1]).

-record(reposition_drone_v1, {
    drone_id    :: binary() | undefined,
    x           :: number() | undefined,
    y           :: number() | undefined,
    alt         :: number() | undefined,
    observed_at :: integer() | undefined
}).

-opaque t() :: #reposition_drone_v1{}.
-export_type([t/0]).

command_type() -> reposition_drone_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{drone_id := Id} = P) ->
    {ok, #reposition_drone_v1{
        drone_id    = Id,
        x           = maps:get(x, P, undefined),
        y           = maps:get(y, P, undefined),
        alt         = maps:get(alt, P, undefined),
        observed_at = maps:get(observed_at, P, undefined)}};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"drone_id">> := Id} = M) ->
    new(#{drone_id => Id,
          x => maps:get(<<"x">>, M, undefined),
          y => maps:get(<<"y">>, M, undefined),
          alt => maps:get(<<"alt">>, M, undefined),
          observed_at => maps:get(<<"observed_at">>, M, undefined)});
from_map(#{drone_id := _} = M) -> new(M);
from_map(_) -> {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#reposition_drone_v1{drone_id = undefined}) -> {error, missing_aggregate_id};
validate(#reposition_drone_v1{x = undefined})        -> {error, missing_position};
validate(#reposition_drone_v1{y = undefined})        -> {error, missing_position};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#reposition_drone_v1{} = C) ->
    #{command_type => <<"reposition_drone">>,
      drone_id     => C#reposition_drone_v1.drone_id,
      x            => C#reposition_drone_v1.x,
      y            => C#reposition_drone_v1.y,
      alt          => C#reposition_drone_v1.alt,
      observed_at  => C#reposition_drone_v1.observed_at}.

-spec stream_id(t()) -> binary().
stream_id(#reposition_drone_v1{drone_id = Id}) ->
    drone_track_aggregate:stream_id(Id).

get_drone_id(#reposition_drone_v1{drone_id = V})       -> V.
get_x(#reposition_drone_v1{x = V})                     -> V.
get_y(#reposition_drone_v1{y = V})                     -> V.
get_alt(#reposition_drone_v1{alt = V})                 -> V.
get_observed_at(#reposition_drone_v1{observed_at = V}) -> V.
