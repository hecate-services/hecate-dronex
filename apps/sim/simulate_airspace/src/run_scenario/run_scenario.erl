%%% @doc Scenario driver. Reads the active scenario and walks each drone along
%%% its path, dispatching enter -> reposition* -> depart as ground-truth
%%% commands. One linked walker process per drone (parksim's per-lot pattern).
%%%
%%% Positions are interpolated between waypoints at one simulated second per
%%% step, so the ground-truth stream has the temporal density the scorer needs
%%% for detection-latency and track-error metrics.
-module(run_scenario).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(LAUNCH_DELAY_MS, 1500).
-define(CYCLE_GAP_MS, 6000).   %% simulated gap between replays in continuous mode

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Defer launch so the store + evoq subscription are up before we dispatch.
init([]) ->
    erlang:send_after(?LAUNCH_DELAY_MS, self(), launch),
    {ok, #{walkers => []}}.

handle_call(_Msg, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)         -> {noreply, State}.

handle_info(launch, State) ->
    Continuous = hecate_dronex_service:continuous(),
    Walkers = [ spawn_link(fun() -> walk(D, Continuous, 1) end) || D <- dronex_scenario:drones() ],
    {noreply, State#{walkers => Walkers}};
handle_info(_Other, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%%--------------------------------------------------------------------
%% Per-drone walk

walk(Drone, Continuous, Cycle) ->
    Base     = maps:get(id, Drone),
    Type     = maps:get(type, Drone, <<"unknown">>),
    RemoteId = maps:get(remote_id, Drone, absent),
    %% A fresh id per cycle in continuous mode: a departed drone leaves its
    %% aggregate "departed", so re-entering the same id would be rejected.
    Id = case Continuous of
             true  -> <<Base/binary, "-", (integer_to_binary(Cycle))/binary>>;
             false -> Base
         end,
    case maps:get(path, Drone, []) of
        [] ->
            ok;
        [#{x := X0, y := Y0, alt := A0} | _] = Path ->
            _ = maybe_enter_airspace:dispatch(#{drone_id => Id, drone_type => Type,
                                                remote_id => RemoteId,
                                                x => X0, y => Y0, alt => A0}),
            walk_path(Id, Path),
            _ = maybe_depart_airspace:dispatch(#{drone_id => Id}),
            continue(Drone, Continuous, Cycle)
    end.

continue(_Drone, false, _Cycle) ->
    ok;
continue(Drone, true, Cycle) ->
    simulate_clock:sleep_simulated(?CYCLE_GAP_MS),
    walk(Drone, true, Cycle + 1).

walk_path(_Id, [_Last]) ->
    ok;
walk_path(Id, [#{t := T1, x := X1, y := Y1, alt := A1},
               #{t := T2, x := X2, y := Y2, alt := A2} = Next | Rest]) ->
    Steps = max(1, round(T2 - T1)),
    lists:foreach(
        fun(I) ->
            F = I / Steps,
            reposition(Id, X1 + (X2 - X1) * F, Y1 + (Y2 - Y1) * F, A1 + (A2 - A1) * F),
            simulate_clock:sleep_simulated(1000)
        end,
        lists:seq(1, Steps)),
    walk_path(Id, [Next | Rest]).

reposition(Id, X, Y, A) ->
    _ = maybe_reposition_drone:dispatch(#{drone_id => Id, x => X, y => Y, alt => A,
                                          observed_at => erlang:system_time(millisecond)}),
    ok.
