%%% @doc Over-mesh integration test for the edge brain.
%%%
%%% Boots `fuse_airspace` (and its store) under an in-memory macula mesh, then
%%% publishes an `airspace.contact_observed` fact "from a sensor on another
%%% node" and asserts the fusion stack publishes an `airspace.track_confirmed`
%%% fact back. This is the swap point exercised over the real mesh path
%%% (macula:subscribe/publish), with no station, no QUIC, and no certificate.
%%%
%%% It is the one thing the CMD and PRJ/QRY suites cannot reach: facts crossing
%%% the mesh between contexts.
-module(fuse_airspace_over_mesh_tests).
-include_lib("eunit/include/eunit.hrl").

-define(SITE, <<"test-site">>).

over_mesh_test_() ->
    {timeout, 60, fun over_mesh/0}.

over_mesh() ->
    Tmp = filename:join("/tmp", "dronex_om_" ++ integer_to_list(erlang:unique_integer([positive]))),
    os:putenv("SITE_ID", binary_to_list(?SITE)),
    os:putenv("DRONEX_ROLE", "edge"),
    os:putenv("HECATE_DATA_DIR", Tmp),
    %% evoq adapter wiring (normally from sys.config; set it for the bare test VM).
    application:set_env(evoq, event_store_adapter, reckon_evoq_adapter),
    application:set_env(evoq, subscription_adapter, reckon_evoq_adapter),
    application:set_env(evoq, snapshot_store_adapter, reckon_evoq_adapter),
    try
        hecate_testkit:with_mesh(fun(Mesh) ->
            {ok, _} = hecate_testkit:boot_service(hecate_dronex_service, #{apps => [fuse_airspace]}),
            %% let the correlator's process manager subscribe to the contact topic
            timer:sleep(500),

            ContactTopic = airspace_contact_observed:topic(?SITE),
            TrackTopic   = airspace_track_confirmed:topic(?SITE),

            %% harness watches for the confirmed-track fact
            ok = hecate_testkit:subscribe(Mesh, TrackTopic),

            %% a sensor (could be real or simulated) publishes a contact
            Contact = airspace_contact_observed:new(#{
                sensor_id  => <<"ne-03">>,
                modality   => remote_id,
                position   => #{x => 80, y => 30, alt => 60},
                drone      => #{id => <<"bogey-1">>, type => <<"DJI Mavic 3">>},
                confidence => 0.95}),
            ok = hecate_testkit:publish(Mesh, ContactTopic, Contact),

            %% fusion correlates it and publishes a confirmed track
            Track = hecate_testkit:await(TrackTopic, fun(F) -> is_map(F) end, 8000),
            ?assertEqual(<<"track-bogey-1">>, airspace_track_confirmed:track_id(Track)),
            ?assertEqual(<<"bogey-1">>, maps:get(id, airspace_track_confirmed:drone(Track)))
        end)
    after
        catch application:stop(fuse_airspace),
        catch cowboy:stop_listener(hecate_dronex_http_listener),
        catch stop_root_sup(),
        catch application:stop(reckon_db),
        catch application:stop(hecate_om),
        catch file:del_dir_r(Tmp)
    end.

%% hecate_om:boot starts hecate_dronex_sup as a named singleton linked to this
%% test process; application:stop can't reach it. Unlink before killing so the
%% kill doesn't propagate back, and wait for it to die so the next store-booting
%% test finds the name free.
stop_root_sup() ->
    case whereis(hecate_dronex_sup) of
        undefined -> ok;
        Pid ->
            unlink(Pid),
            MRef = monitor(process, Pid),
            exit(Pid, kill),
            receive {'DOWN', MRef, process, Pid, _} -> ok after 5000 -> ok end
    end.
