%%% @doc Airspace-track state: init + event folding.
-module(air_track_state).
-behaviour(evoq_state).

-include("air_track_state.hrl").
-include("air_track_status.hrl").

-export([new/1, apply_event/2, to_map/1]).
-export([track_id/1, is_confirmed/1]).

-type state() :: #air_track_state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(TrackId) ->
    #air_track_state{track_id = TrackId}.

-spec apply_event(state(), map()) -> state().
apply_event(#air_track_state{status_flags = F} = S,
            #{event_type := <<"track_confirmed">>} = Ev) ->
    S#air_track_state{
        status_flags  = evoq_bit_flags:set(F, ?TRACK_CONFIRMED),
        drone         = g(drone, Ev, S#air_track_state.drone),
        x             = g(x, Ev, S#air_track_state.x),
        y             = g(y, Ev, S#air_track_state.y),
        alt           = g(alt, Ev, S#air_track_state.alt),
        confidence    = g(confidence, Ev, S#air_track_state.confidence),
        sensor_ids    = g(sensor_ids, Ev, S#air_track_state.sensor_ids),
        first_seen_at = g(first_seen_at, Ev, S#air_track_state.first_seen_at),
        confirmed_at  = g(confirmed_at, Ev, S#air_track_state.confirmed_at)};
apply_event(S, _UnknownEvent) ->
    S.

-spec to_map(state()) -> map().
to_map(#air_track_state{} = S) ->
    #{track_id     => S#air_track_state.track_id,
      drone        => S#air_track_state.drone,
      status_flags => S#air_track_state.status_flags,
      x            => S#air_track_state.x,
      y            => S#air_track_state.y,
      alt          => S#air_track_state.alt,
      confidence   => S#air_track_state.confidence}.

track_id(#air_track_state{track_id = V}) -> V.

is_confirmed(#air_track_state{status_flags = F}) ->
    evoq_bit_flags:has(F, ?TRACK_CONFIRMED).

%%--------------------------------------------------------------------

g(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   ->
            case maps:find(atom_to_binary(Key, utf8), Map) of
                {ok, V} -> V;
                error   -> Default
            end
    end.
