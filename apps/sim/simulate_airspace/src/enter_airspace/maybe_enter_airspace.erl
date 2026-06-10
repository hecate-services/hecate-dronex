%%% @doc Handler for enter_airspace. Validates, guards against a double entry,
%%% emits drone_entered_airspace_v1. dispatch/1 sends it through evoq.
-module(maybe_enter_airspace).

-export([handle/1, handle/2, dispatch/1]).

-spec handle(enter_airspace_v1:t()) ->
    {ok, [drone_entered_airspace_v1:t()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, drone_track_state:new(<<>>)).

-spec handle(enter_airspace_v1:t(), drone_track_state:state()) ->
    {ok, [drone_entered_airspace_v1:t()]} | {error, term()}.
handle(Cmd, State) ->
    case enter_airspace_v1:validate(Cmd) of
        ok ->
            case drone_track_state:is_in_airspace(State) of
                true  -> {error, drone_already_in_airspace};
                false -> emit(Cmd)
            end;
        {error, _} = E -> E
    end.

emit(Cmd) ->
    EnteredAt = case enter_airspace_v1:get_entered_at(Cmd) of
                    undefined -> erlang:system_time(millisecond);
                    T         -> T
                end,
    {ok, Ev} = drone_entered_airspace_v1:new(#{
        drone_id   => enter_airspace_v1:get_drone_id(Cmd),
        drone_type => enter_airspace_v1:get_drone_type(Cmd),
        remote_id  => enter_airspace_v1:get_remote_id(Cmd),
        x          => enter_airspace_v1:get_x(Cmd),
        y          => enter_airspace_v1:get_y(Cmd),
        alt        => enter_airspace_v1:get_alt(Cmd),
        entered_at => EnteredAt}),
    {ok, [Ev]}.

-spec dispatch(enter_airspace_v1:t() | map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(#{} = Data) ->
    case enter_airspace_v1:from_map(Data) of
        {ok, Cmd}      -> dispatch(Cmd);
        {error, _} = E -> E
    end;
dispatch(Cmd) ->
    DroneId = enter_airspace_v1:get_drone_id(Cmd),
    EvoqCmd = evoq_command:new(
        enter_airspace, drone_track_aggregate,
        drone_track_aggregate:stream_id(DroneId),
        enter_airspace_v1:to_map(Cmd),
        #{timestamp => erlang:system_time(millisecond)}),
    Opts = #{store_id    => hecate_dronex_service:store_id(),
             adapter     => reckon_evoq_adapter,
             consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
