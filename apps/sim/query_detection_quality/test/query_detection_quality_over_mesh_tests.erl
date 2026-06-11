%%% @doc Full-loop over-mesh integration test.
%%%
%%% Boots all four dronex_sim apps + the store under an in-memory macula mesh,
%%% runs the `perimeter_probe` scenario, and asserts the scoring oracle sees the
%%% drone detected end to end:
%%%
%%%   simulate_airspace (ground truth) -> observe_remote_id (publishes
%%%   contact_observed) -> fuse_airspace (publishes track_confirmed) ->
%%%   query_detection_quality (records the estimate, scores it).
%%%
%%% Every fact crosses the in-memory mesh; no station, no QUIC, no certificate.
-module(query_detection_quality_over_mesh_tests).
-include_lib("eunit/include/eunit.hrl").

-define(SITE, <<"loop-site">>).
-define(APPS, [simulate_airspace, observe_remote_id, fuse_airspace, query_detection_quality]).

full_loop_test_() ->
    {timeout, 90, fun full_loop/0}.

full_loop() ->
    Tmp = filename:join("/tmp", "dronex_loop_" ++ integer_to_list(erlang:unique_integer([positive]))),
    os:putenv("SITE_ID", binary_to_list(?SITE)),
    os:putenv("DRONEX_ROLE", "sim"),
    os:putenv("DRONEX_SCENARIO", "perimeter_probe"),
    os:putenv("DRONEX_TIME_SCALE", "100"),   %% compress the 90s walk to ~1s
    os:putenv("DRONEX_SEED", "1"),
    os:putenv("HECATE_DATA_DIR", Tmp),
    application:set_env(evoq, event_store_adapter, reckon_evoq_adapter),
    application:set_env(evoq, subscription_adapter, reckon_evoq_adapter),
    application:set_env(evoq, snapshot_store_adapter, reckon_evoq_adapter),
    try
        hecate_testkit:with_mesh(fun(_Mesh) ->
            {ok, _} = hecate_testkit:boot_service(hecate_dronex_service, #{apps => ?APPS}),
            %% The scenario driver launches after ~1.5s and walks the drone;
            %% facts then flow across the mesh. Poll the scorer until fusion has
            %% detected the drone end to end (robust to the async pipeline).
            ok = poll_until_detected(250, 100),
            Scores = score_detection:overview(),
            ?assertEqual(1, maps:get(detected, Scores)),
            ?assertEqual(0, maps:get(missed, Scores)),
            ?assertEqual(0, maps:get(false_tracks, Scores)),
            ?assert(maps:get(ground_truth_drones, Scores) >= 1)
        end)
    after
        catch [application:stop(A) || A <- lists:reverse(?APPS)],
        catch cowboy:stop_listener(hecate_dronex_http_listener),
        catch stop_root_sup(),
        catch application:stop(reckon_db),
        catch application:stop(hecate_om),
        catch file:del_dir_r(Tmp)
    end.

%% hecate_om:boot starts hecate_dronex_sup as a named singleton linked to this
%% test process; application:stop can't reach it. Unlink before killing so the
%% kill doesn't propagate back, and wait for it to actually die so the next
%% store-booting test finds the name free.
stop_root_sup() ->
    case whereis(hecate_dronex_sup) of
        undefined -> ok;
        Pid ->
            unlink(Pid),
            MRef = monitor(process, Pid),
            exit(Pid, kill),
            receive {'DOWN', MRef, process, Pid, _} -> ok after 5000 -> ok end
    end.

poll_until_detected(0, _Interval) ->
    erlang:error({no_detection, catch score_detection:overview()});
poll_until_detected(N, IntervalMs) ->
    case catch score_detection:overview() of
        #{detected := D} when D >= 1 -> ok;
        _ ->
            timer:sleep(IntervalMs),
            poll_until_detected(N - 1, IntervalMs)
    end.
