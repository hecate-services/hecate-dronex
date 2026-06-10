%%% @doc The ground-truth oracle: scores fusion against known truth.
%%%
%%% Because the simulator owns ground truth, every run yields hard metrics:
%%% detection latency, track positional error (RMSE), missed-detection rate,
%%% false-track rate, and a coarse id accuracy. These are the CI gate and the
%%% demo/grant headline.
-module(score_detection).

-export([overview/0]).

-spec overview() -> map().
overview() ->
    Gt       = query_detection_quality_store:ground_truth_drones(),
    Est      = query_detection_quality_store:estimate_drones(),
    Detected = [D || D <- Gt, lists:member(D, Est)],
    Missed   = [D || D <- Gt, not lists:member(D, Est)],
    Latencies = [L || D <- Detected, {ok, L} <- [latency(D)]],
    Rmses     = [R || D <- Detected, {ok, R} <- [rmse(D)]],
    #{ground_truth_drones    => length(Gt),
      detected               => length(Detected),
      missed                 => length(Missed),
      missed_rate            => ratio(length(Missed), length(Gt)),
      false_tracks           => query_detection_quality_store:false_track_count(),
      id_accuracy            => ratio(length(Detected), length(Est)),
      mean_detect_latency_ms => mean(Latencies),
      mean_track_rmse_m      => mean(Rmses)}.

%%--------------------------------------------------------------------

latency(DroneId) ->
    case {query_detection_quality_store:entry_time(DroneId),
          query_detection_quality_store:first_estimate_time(DroneId)} of
        {{ok, Entry}, {ok, First}} -> {ok, First - Entry};
        _                          -> error
    end.

%% RMS of each estimate point's distance to the nearest-in-time ground-truth
%% point for the same drone.
rmse(DroneId) ->
    Gt  = query_detection_quality_store:ground_truth_points(DroneId),
    Est = query_detection_quality_store:estimate_points(DroneId),
    case {Gt, Est} of
        {[_ | _], [_ | _]} ->
            Sq = [ d2(EX, EY, nearest(ET, Gt)) || {ET, EX, EY} <- Est ],
            {ok, math:sqrt(mean(Sq))};
        _ ->
            error
    end.

nearest(T, Points) ->
    [{_, X, Y} | _] = lists:sort(
        fun({Ta, _, _}, {Tb, _, _}) -> abs(Ta - T) =< abs(Tb - T) end, Points),
    {X, Y}.

d2(EX, EY, {GX, GY}) ->
    DX = EX - GX, DY = EY - GY,
    DX * DX + DY * DY.

mean([])   -> 0.0;
mean(Xs)   -> lists:sum(Xs) / length(Xs).

ratio(_, 0) -> 0.0;
ratio(A, B) -> A / B.
