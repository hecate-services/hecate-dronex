%%% @doc Airspace-track aggregate (evoq_aggregate). One stream per track.
-module(air_track_aggregate).
-behaviour(evoq_aggregate).

-include("air_track_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).
-export([stream_id/1]).

-type state() :: air_track_state:state().

-spec state_module() -> module().
state_module() -> air_track_state.

-spec init(binary()) -> {ok, state()}.
init(TrackId) ->
    {ok, air_track_state:new(TrackId)}.

-spec stream_id(binary()) -> binary().
stream_id(TrackId) when is_binary(TrackId) ->
    Hex = binary:encode_hex(crypto:hash(md5, TrackId), lowercase),
    <<"trk-", Hex/binary>>.

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"confirm_track">>} = P) ->
    route(confirm_track_v1, maybe_confirm_track, track_confirmed_v1, State, P);
execute(_State, #{command_type := Other}) ->
    {error, {unhandled_command, Other}};
execute(_State, _Payload) ->
    {error, missing_command_type}.

route(CmdMod, HandlerMod, EventMod, State, Payload) ->
    case CmdMod:from_map(Payload) of
        {ok, Cmd} ->
            case HandlerMod:handle(Cmd, State) of
                {ok, Events}   -> {ok, [EventMod:to_map(E) || E <- Events]};
                {error, _} = E -> E
            end;
        {error, _} = E -> E
    end.

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    air_track_state:apply_event(State, Event).
