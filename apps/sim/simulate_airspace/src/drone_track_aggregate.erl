%%% @doc Ground-truth drone-track aggregate (evoq_aggregate).
%%%
%%% One stream per simulated drone. Routes the three lifecycle commands to
%%% their handlers and folds the resulting events into drone_track_state.
-module(drone_track_aggregate).
-behaviour(evoq_aggregate).

-include("drone_track_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).
-export([stream_id/1]).

-type state() :: drone_track_state:state().

-spec state_module() -> module().
state_module() -> drone_track_state.

-spec init(binary()) -> {ok, state()}.
init(DroneId) ->
    {ok, drone_track_state:new(DroneId)}.

%% @doc reckon-db rejects stream ids that don't match `^[a-z]{1,32}-[a-f0-9]{32}$`.
%% Derive a stable, compliant id as `drn-<md5(drone_id)>`.
-spec stream_id(binary()) -> binary().
stream_id(DroneId) when is_binary(DroneId) ->
    Hex = binary:encode_hex(crypto:hash(md5, DroneId), lowercase),
    <<"drn-", Hex/binary>>.

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"enter_airspace">>} = P) ->
    route(enter_airspace_v1, maybe_enter_airspace, drone_entered_airspace_v1, State, P);
execute(State, #{command_type := <<"reposition_drone">>} = P) ->
    route(reposition_drone_v1, maybe_reposition_drone, drone_repositioned_v1, State, P);
execute(State, #{command_type := <<"depart_airspace">>} = P) ->
    route(depart_airspace_v1, maybe_depart_airspace, drone_departed_v1, State, P);
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
    drone_track_state:apply_event(State, Event).
