%%% @doc PRJ + QRY tests for the scoring oracle, against a real temp SQLite.
%%%
%%% Drives the ground-truth projection (project/4) and the estimate recorder's
%%% store directly, then asserts score_detection's metrics. No mesh: the
%%% projection's store write and the scorer's reads are all single-process.
-module(detection_quality_tests).
-include_lib("eunit/include/eunit.hrl").

quality_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun detected_and_scored/1,
        fun missed_drone/1,
        fun false_track/1
    ]}.

%%--------------------------------------------------------------------
%% fixtures: a fresh temp store per test

setup() ->
    Tmp = filename:join("/tmp", "dronex_dq_" ++ integer_to_list(erlang:unique_integer([positive]))),
    os:putenv("HECATE_DATA_DIR", Tmp),
    {ok, Pid} = query_detection_quality_store:start_link(),
    {Pid, Tmp}.

cleanup({Pid, Tmp}) ->
    gen_server:stop(Pid),
    _ = file:del_dir_r(Tmp),
    ok.

%%--------------------------------------------------------------------
%% cases

%% A confirmed track that matches the truth: detected, latency = first
%% confirm minus entry, RMSE = 0 against the coincident ground-truth point.
detected_and_scored(_) ->
    {"detected, latency + zero RMSE", fun() ->
        project_ground_truth(<<"bogey-1">>, 1000, [{1001, 10, 0}, {1002, 20, 0}]),
        query_detection_quality_store:record_estimate(<<"track-1">>, <<"bogey-1">>, 1003, 20, 0, 0.95),
        #{detected := D, missed := M, false_tracks := F,
          mean_detect_latency_ms := Lat, mean_track_rmse_m := Rmse,
          id_accuracy := Acc} = score_detection:overview(),
        ?assertEqual(1, D),
        ?assertEqual(0, M),
        ?assertEqual(0, F),
        ?assertEqual(3.0, Lat),
        ?assertEqual(0.0, Rmse),
        ?assertEqual(1.0, Acc)
    end}.

%% Ground truth with no estimate: missed, missed_rate 1.0.
missed_drone(_) ->
    {"missed detection", fun() ->
        project_ground_truth(<<"bogey-2">>, 2000, [{2001, 5, 5}]),
        #{detected := D, missed := M, missed_rate := MR} = score_detection:overview(),
        ?assertEqual(0, D),
        ?assertEqual(1, M),
        ?assertEqual(1.0, MR)
    end}.

%% An estimate whose drone is not in ground truth: a false track.
false_track(_) ->
    {"false track counted", fun() ->
        project_ground_truth(<<"bogey-1">>, 1000, [{1001, 10, 0}]),
        query_detection_quality_store:record_estimate(<<"t1">>, <<"bogey-1">>, 1002, 10, 0, 0.9),
        query_detection_quality_store:record_estimate(<<"ghost-track">>, <<"ghost">>, 1002, 99, 99, 0.4),
        #{detected := D, false_tracks := F} = score_detection:overview(),
        ?assertEqual(1, D),
        ?assertEqual(1, F)
    end}.

%%--------------------------------------------------------------------
%% helper: feed ground-truth events through the real projection

project_ground_truth(DroneId, EnteredAt, Repositions) ->
    Enter = #{event_type => <<"drone_entered_airspace">>,
              data => #{drone_id => DroneId, x => 0, y => 0, alt => 0, entered_at => EnteredAt}},
    {ok, _, _} = drone_repositioned_to_ground_truth:project(Enter, #{}, #{}, undefined),
    lists:foreach(
        fun({T, X, Y}) ->
            Ev = #{event_type => <<"drone_repositioned">>,
                   data => #{drone_id => DroneId, x => X, y => Y, alt => 0, observed_at => T}},
            {ok, _, _} = drone_repositioned_to_ground_truth:project(Ev, #{}, #{}, undefined)
        end,
        Repositions),
    ok.
