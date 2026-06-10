%%% @doc Command `confirm_track_v1`. Fusion has correlated enough evidence to
%%% promote contacts into a confirmed, escalation-grade track.
-module(confirm_track_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1, stream_id/1]).
-export([get_track_id/1, get_drone/1, get_x/1, get_y/1, get_alt/1,
         get_confidence/1, get_sensor_ids/1, get_first_seen_at/1]).

-record(confirm_track_v1, {
    track_id      :: binary() | undefined,
    drone         :: map() | undefined,
    x             :: number() | undefined,
    y             :: number() | undefined,
    alt           :: number() | undefined,
    confidence    :: float() | undefined,
    sensor_ids    :: [binary()] | undefined,
    first_seen_at :: integer() | undefined
}).

-type t() :: #confirm_track_v1{}.
-export_type([t/0]).

command_type() -> confirm_track_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{track_id := Id} = P) ->
    {ok, #confirm_track_v1{
        track_id      = Id,
        drone         = maps:get(drone, P, #{}),
        x             = maps:get(x, P, undefined),
        y             = maps:get(y, P, undefined),
        alt           = maps:get(alt, P, undefined),
        confidence    = maps:get(confidence, P, 0.0),
        sensor_ids    = maps:get(sensor_ids, P, []),
        first_seen_at = maps:get(first_seen_at, P, undefined)}};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"track_id">> := Id} = M) ->
    new(#{track_id => Id,
          drone => maps:get(<<"drone">>, M, #{}),
          x => maps:get(<<"x">>, M, undefined),
          y => maps:get(<<"y">>, M, undefined),
          alt => maps:get(<<"alt">>, M, undefined),
          confidence => maps:get(<<"confidence">>, M, 0.0),
          sensor_ids => maps:get(<<"sensor_ids">>, M, []),
          first_seen_at => maps:get(<<"first_seen_at">>, M, undefined)});
from_map(#{track_id := _} = M) -> new(M);
from_map(_) -> {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#confirm_track_v1{track_id = undefined}) -> {error, missing_aggregate_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#confirm_track_v1{} = C) ->
    #{command_type  => <<"confirm_track">>,
      track_id      => C#confirm_track_v1.track_id,
      drone         => C#confirm_track_v1.drone,
      x             => C#confirm_track_v1.x,
      y             => C#confirm_track_v1.y,
      alt           => C#confirm_track_v1.alt,
      confidence    => C#confirm_track_v1.confidence,
      sensor_ids    => C#confirm_track_v1.sensor_ids,
      first_seen_at => C#confirm_track_v1.first_seen_at}.

-spec stream_id(t()) -> binary().
stream_id(#confirm_track_v1{track_id = Id}) ->
    air_track_aggregate:stream_id(Id).

get_track_id(#confirm_track_v1{track_id = V})           -> V.
get_drone(#confirm_track_v1{drone = V})                 -> V.
get_x(#confirm_track_v1{x = V})                         -> V.
get_y(#confirm_track_v1{y = V})                         -> V.
get_alt(#confirm_track_v1{alt = V})                     -> V.
get_confidence(#confirm_track_v1{confidence = V})       -> V.
get_sensor_ids(#confirm_track_v1{sensor_ids = V})       -> V.
get_first_seen_at(#confirm_track_v1{first_seen_at = V}) -> V.
