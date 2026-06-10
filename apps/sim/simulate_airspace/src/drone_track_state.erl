%%% @doc Ground-truth drone-track state: init + event folding.
-module(drone_track_state).
-behaviour(evoq_state).

-include("drone_track_state.hrl").
-include("drone_track_status.hrl").

-export([new/1, apply_event/2, to_map/1]).
-export([drone_id/1, drone_type/1, remote_id/1, position/1,
         is_in_airspace/1, is_departed/1]).

-type state() :: #drone_track_state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(DroneId) ->
    #drone_track_state{drone_id = DroneId}.

-spec apply_event(state(), map()) -> state().
apply_event(#drone_track_state{status_flags = F} = S,
            #{event_type := <<"drone_entered_airspace">>} = Ev) ->
    S#drone_track_state{
        status_flags = evoq_bit_flags:set(F, ?DRONE_IN_AIRSPACE),
        drone_type   = g(drone_type, Ev, S#drone_track_state.drone_type),
        remote_id    = remote_id_atom(g(remote_id, Ev, S#drone_track_state.remote_id)),
        x            = g(x, Ev, S#drone_track_state.x),
        y            = g(y, Ev, S#drone_track_state.y),
        alt          = g(alt, Ev, S#drone_track_state.alt),
        entered_at   = g(entered_at, Ev, S#drone_track_state.entered_at)};
apply_event(#drone_track_state{} = S,
            #{event_type := <<"drone_repositioned">>} = Ev) ->
    S#drone_track_state{
        x   = g(x, Ev, S#drone_track_state.x),
        y   = g(y, Ev, S#drone_track_state.y),
        alt = g(alt, Ev, S#drone_track_state.alt)};
apply_event(#drone_track_state{status_flags = F} = S,
            #{event_type := <<"drone_departed">>} = Ev) ->
    S#drone_track_state{
        status_flags = evoq_bit_flags:set(F, ?DRONE_DEPARTED),
        departed_at  = g(departed_at, Ev, S#drone_track_state.departed_at)};
apply_event(S, _UnknownEvent) ->
    S.

-spec to_map(state()) -> map().
to_map(#drone_track_state{} = S) ->
    #{drone_id     => S#drone_track_state.drone_id,
      drone_type   => S#drone_track_state.drone_type,
      remote_id    => S#drone_track_state.remote_id,
      status_flags => S#drone_track_state.status_flags,
      x            => S#drone_track_state.x,
      y            => S#drone_track_state.y,
      alt          => S#drone_track_state.alt}.

drone_id(#drone_track_state{drone_id = V})     -> V.
drone_type(#drone_track_state{drone_type = V}) -> V.
remote_id(#drone_track_state{remote_id = V})   -> V.
position(#drone_track_state{x = X, y = Y, alt = A}) -> #{x => X, y => Y, alt => A}.

is_in_airspace(#drone_track_state{status_flags = F}) ->
    evoq_bit_flags:has(F, ?DRONE_IN_AIRSPACE).
is_departed(#drone_track_state{status_flags = F}) ->
    evoq_bit_flags:has(F, ?DRONE_DEPARTED).

%%--------------------------------------------------------------------

remote_id_atom(present) -> present;
remote_id_atom(absent)  -> absent;
remote_id_atom(<<"present">>) -> present;
remote_id_atom(<<"absent">>)  -> absent;
remote_id_atom(_) -> undefined.

g(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   ->
            case maps:find(atom_to_binary(Key, utf8), Map) of
                {ok, V} -> V;
                error   -> Default
            end
    end.
