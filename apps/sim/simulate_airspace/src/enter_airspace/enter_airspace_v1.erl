%%% @doc Command `enter_airspace_v1`. A drone appears in the site airspace.
-module(enter_airspace_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1, stream_id/1]).
-export([get_drone_id/1, get_drone_type/1, get_remote_id/1,
         get_x/1, get_y/1, get_alt/1, get_entered_at/1]).

-record(enter_airspace_v1, {
    drone_id   :: binary() | undefined,
    drone_type :: binary() | undefined,
    remote_id  :: present | absent | undefined,
    x          :: number() | undefined,
    y          :: number() | undefined,
    alt        :: number() | undefined,
    entered_at :: integer() | undefined
}).

-opaque t() :: #enter_airspace_v1{}.
-export_type([t/0]).

command_type() -> enter_airspace_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{drone_id := Id} = P) ->
    {ok, #enter_airspace_v1{
        drone_id   = Id,
        drone_type = maps:get(drone_type, P, undefined),
        remote_id  = maps:get(remote_id, P, absent),
        x          = maps:get(x, P, undefined),
        y          = maps:get(y, P, undefined),
        alt        = maps:get(alt, P, undefined),
        entered_at = maps:get(entered_at, P, undefined)}};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"drone_id">> := Id} = M) -> build(Id, M, fun bget/3);
from_map(#{drone_id := Id} = M)       -> build(Id, M, fun maps:get/3);
from_map(_)                           -> {error, missing_aggregate_id}.

build(Id, M, Get) ->
    {ok, #enter_airspace_v1{
        drone_id   = Id,
        drone_type = Get(drone_type, M, undefined),
        remote_id  = Get(remote_id, M, absent),
        x          = Get(x, M, undefined),
        y          = Get(y, M, undefined),
        alt        = Get(alt, M, undefined),
        entered_at = Get(entered_at, M, undefined)}}.

-spec validate(t()) -> ok | {error, term()}.
validate(#enter_airspace_v1{drone_id = undefined}) -> {error, missing_aggregate_id};
validate(#enter_airspace_v1{x = undefined})        -> {error, missing_position};
validate(#enter_airspace_v1{y = undefined})        -> {error, missing_position};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#enter_airspace_v1{} = C) ->
    #{command_type => <<"enter_airspace">>,
      drone_id     => C#enter_airspace_v1.drone_id,
      drone_type   => C#enter_airspace_v1.drone_type,
      remote_id    => C#enter_airspace_v1.remote_id,
      x            => C#enter_airspace_v1.x,
      y            => C#enter_airspace_v1.y,
      alt          => C#enter_airspace_v1.alt,
      entered_at   => C#enter_airspace_v1.entered_at}.

-spec stream_id(t()) -> binary().
stream_id(#enter_airspace_v1{drone_id = Id}) ->
    drone_track_aggregate:stream_id(Id).

get_drone_id(#enter_airspace_v1{drone_id = V})     -> V.
get_drone_type(#enter_airspace_v1{drone_type = V}) -> V.
get_remote_id(#enter_airspace_v1{remote_id = V})   -> V.
get_x(#enter_airspace_v1{x = V})                   -> V.
get_y(#enter_airspace_v1{y = V})                   -> V.
get_alt(#enter_airspace_v1{alt = V})               -> V.
get_entered_at(#enter_airspace_v1{entered_at = V}) -> V.

bget(Key, M, Default) -> maps:get(atom_to_binary(Key, utf8), M, Default).
