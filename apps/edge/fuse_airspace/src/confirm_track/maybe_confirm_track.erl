%%% @doc Handler for confirm_track. Confirms a track once; a second confirm for
%%% an already-confirmed track is a no-op decision (the correlator updates the
%%% live position via the published fact, not a new domain event).
-module(maybe_confirm_track).

-export([handle/1, handle/2, dispatch/1]).

-spec handle(confirm_track_v1:t()) ->
    {ok, [track_confirmed_v1:t()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, air_track_state:new(<<>>)).

-spec handle(confirm_track_v1:t(), air_track_state:state()) ->
    {ok, [track_confirmed_v1:t()]} | {error, term()}.
handle(Cmd, State) ->
    case confirm_track_v1:validate(Cmd) of
        ok ->
            case air_track_state:is_confirmed(State) of
                true  -> {error, track_already_confirmed};
                false -> emit(Cmd)
            end;
        {error, _} = E -> E
    end.

emit(Cmd) ->
    {ok, Ev} = track_confirmed_v1:new(#{
        track_id      => confirm_track_v1:get_track_id(Cmd),
        drone         => confirm_track_v1:get_drone(Cmd),
        x             => confirm_track_v1:get_x(Cmd),
        y             => confirm_track_v1:get_y(Cmd),
        alt           => confirm_track_v1:get_alt(Cmd),
        confidence    => confirm_track_v1:get_confidence(Cmd),
        sensor_ids    => confirm_track_v1:get_sensor_ids(Cmd),
        first_seen_at => confirm_track_v1:get_first_seen_at(Cmd),
        confirmed_at  => erlang:system_time(millisecond)}),
    {ok, [Ev]}.

-spec dispatch(confirm_track_v1:t() | map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(#{} = Data) ->
    case confirm_track_v1:from_map(Data) of
        {ok, Cmd}      -> dispatch(Cmd);
        {error, _} = E -> E
    end;
dispatch(Cmd) ->
    TrackId = confirm_track_v1:get_track_id(Cmd),
    EvoqCmd = evoq_command:new(
        confirm_track, air_track_aggregate,
        air_track_aggregate:stream_id(TrackId),
        confirm_track_v1:to_map(Cmd),
        #{timestamp => erlang:system_time(millisecond)}),
    Opts = #{store_id    => hecate_dronex_service:store_id(),
             adapter     => reckon_evoq_adapter,
             consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
