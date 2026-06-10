%%% @doc Handler for reposition_drone. Only a drone that is in the airspace and
%%% has not departed may move.
-module(maybe_reposition_drone).

-export([handle/1, handle/2, dispatch/1]).

-spec handle(reposition_drone_v1:t()) ->
    {ok, [drone_repositioned_v1:t()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, drone_track_state:new(<<>>)).

-spec handle(reposition_drone_v1:t(), drone_track_state:state()) ->
    {ok, [drone_repositioned_v1:t()]} | {error, term()}.
handle(Cmd, State) ->
    case reposition_drone_v1:validate(Cmd) of
        ok ->
            InAirspace = drone_track_state:is_in_airspace(State),
            Departed   = drone_track_state:is_departed(State),
            guard(InAirspace, Departed, Cmd);
        {error, _} = E -> E
    end.

guard(false, _Departed, _Cmd) -> {error, drone_not_in_airspace};
guard(true, true, _Cmd)       -> {error, drone_already_departed};
guard(true, false, Cmd)       -> emit(Cmd).

emit(Cmd) ->
    {ok, Ev} = drone_repositioned_v1:new(#{
        drone_id    => reposition_drone_v1:get_drone_id(Cmd),
        x           => reposition_drone_v1:get_x(Cmd),
        y           => reposition_drone_v1:get_y(Cmd),
        alt         => reposition_drone_v1:get_alt(Cmd),
        observed_at => reposition_drone_v1:get_observed_at(Cmd)}),
    {ok, [Ev]}.

-spec dispatch(reposition_drone_v1:t() | map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(#{} = Data) ->
    case reposition_drone_v1:from_map(Data) of
        {ok, Cmd}      -> dispatch(Cmd);
        {error, _} = E -> E
    end;
dispatch(Cmd) ->
    DroneId = reposition_drone_v1:get_drone_id(Cmd),
    EvoqCmd = evoq_command:new(
        reposition_drone, drone_track_aggregate,
        drone_track_aggregate:stream_id(DroneId),
        reposition_drone_v1:to_map(Cmd),
        #{timestamp => erlang:system_time(millisecond)}),
    Opts = #{store_id    => hecate_dronex_service:store_id(),
             adapter     => reckon_evoq_adapter,
             consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
