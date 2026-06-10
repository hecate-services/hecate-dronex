%%% @doc Handler for depart_airspace. Only a drone currently in the airspace
%%% can depart.
-module(maybe_depart_airspace).

-export([handle/1, handle/2, dispatch/1]).

-spec handle(depart_airspace_v1:t()) ->
    {ok, [drone_departed_v1:t()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, drone_track_state:new(<<>>)).

-spec handle(depart_airspace_v1:t(), drone_track_state:state()) ->
    {ok, [drone_departed_v1:t()]} | {error, term()}.
handle(Cmd, State) ->
    case depart_airspace_v1:validate(Cmd) of
        ok ->
            case drone_track_state:is_in_airspace(State) of
                false -> {error, drone_not_in_airspace};
                true  -> emit(Cmd)
            end;
        {error, _} = E -> E
    end.

emit(Cmd) ->
    DepartedAt = case depart_airspace_v1:get_departed_at(Cmd) of
                     undefined -> erlang:system_time(millisecond);
                     T         -> T
                 end,
    {ok, Ev} = drone_departed_v1:new(#{
        drone_id    => depart_airspace_v1:get_drone_id(Cmd),
        departed_at => DepartedAt}),
    {ok, [Ev]}.

-spec dispatch(depart_airspace_v1:t() | map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(#{} = Data) ->
    case depart_airspace_v1:from_map(Data) of
        {ok, Cmd}      -> dispatch(Cmd);
        {error, _} = E -> E
    end;
dispatch(Cmd) ->
    DroneId = depart_airspace_v1:get_drone_id(Cmd),
    EvoqCmd = evoq_command:new(
        depart_airspace, drone_track_aggregate,
        drone_track_aggregate:stream_id(DroneId),
        depart_airspace_v1:to_map(Cmd),
        #{timestamp => erlang:system_time(millisecond)}),
    Opts = #{store_id    => hecate_dronex_service:store_id(),
             adapter     => reckon_evoq_adapter,
             consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
