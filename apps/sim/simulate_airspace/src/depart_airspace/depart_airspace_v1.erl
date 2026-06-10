%%% @doc Command `depart_airspace_v1`. The drone left the site airspace.
-module(depart_airspace_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1, stream_id/1]).
-export([get_drone_id/1, get_departed_at/1]).

-record(depart_airspace_v1, {
    drone_id    :: binary() | undefined,
    departed_at :: integer() | undefined
}).

-type t() :: #depart_airspace_v1{}.
-export_type([t/0]).

command_type() -> depart_airspace_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{drone_id := Id} = P) ->
    {ok, #depart_airspace_v1{
        drone_id    = Id,
        departed_at = maps:get(departed_at, P, undefined)}};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"drone_id">> := Id} = M) ->
    new(#{drone_id => Id, departed_at => maps:get(<<"departed_at">>, M, undefined)});
from_map(#{drone_id := _} = M) -> new(M);
from_map(_) -> {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#depart_airspace_v1{drone_id = undefined}) -> {error, missing_aggregate_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#depart_airspace_v1{} = C) ->
    #{command_type => <<"depart_airspace">>,
      drone_id     => C#depart_airspace_v1.drone_id,
      departed_at  => C#depart_airspace_v1.departed_at}.

-spec stream_id(t()) -> binary().
stream_id(#depart_airspace_v1{drone_id = Id}) ->
    drone_track_aggregate:stream_id(Id).

get_drone_id(#depart_airspace_v1{drone_id = V})       -> V.
get_departed_at(#depart_airspace_v1{departed_at = V}) -> V.
