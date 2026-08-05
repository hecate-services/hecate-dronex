%%% @doc Pure tests for the Remote-ID sensor model: the uncertainty logic that
%%% is the whole point of a useful simulator (presence, range gate, detection
%%% probability, GPS noise). No store, no mesh.
-module(remote_id_sensor_model_tests).
-include_lib("eunit/include/eunit.hrl").

sensor() ->
    #{id => <<"ne-03">>, modality => remote_id, x => 0, y => 0,
      range_m => 800, p_detect => 1.0}.

drone(RemoteId, X, Y) ->
    #{drone_id => <<"bogey-1">>, drone_type => <<"DJI Mavic 3">>,
      remote_id => RemoteId, x => X, y => Y, alt => 50, observed_at => 1234}.

env() -> #{wind_ms => 6, visibility => low}.

%% Broadcasting + in range + certain detection -> a well-formed contact fact.
broadcasting_in_range_detected_test() ->
    {ok, Fact} = remote_id_sensor_model:observe(drone(present, 100, 0), sensor(), env()),
    ?assertEqual(remote_id, airspace_contact_observed:modality(Fact)),
    ?assertEqual(<<"ne-03">>, airspace_contact_observed:sensor_id(Fact)),
    ?assertEqual(<<"bogey-1">>, maps:get(id, airspace_contact_observed:drone(Fact))),
    ?assertEqual(1234, airspace_contact_observed:observed_at(Fact)),
    ?assert(airspace_contact_observed:confidence(Fact) > 0.5),
    ?assert(is_map(airspace_contact_observed:position(Fact))).

%% Remote ID absent (non-compliant / autonomous): invisible to this modality.
absent_remote_id_is_miss_test() ->
    ?assertEqual(miss, remote_id_sensor_model:observe(drone(absent, 100, 0), sensor(), env())).

%% Detection probability 0 -> never detected, even in range.
zero_p_detect_is_miss_test() ->
    S = (sensor())#{p_detect => 0.0},
    ?assertEqual(miss, remote_id_sensor_model:observe(drone(present, 100, 0), S, env())).

%% Beyond sensor range -> miss, regardless of detection probability.
out_of_range_is_miss_test() ->
    ?assertEqual(miss, remote_id_sensor_model:observe(drone(present, 2000, 0), sensor(), env())).

%% Reported position sits near the truth (GPS-grade noise, ~3m sigma).
position_near_truth_test() ->
    rand:seed(exsss, {1, 2, 3}),
    {ok, Fact} = remote_id_sensor_model:observe(drone(present, 100, 0), sensor(), env()),
    Pos = airspace_contact_observed:position(Fact),
    ?assert(abs(maps:get(x, Pos) - 100) < 30),
    ?assert(abs(maps:get(y, Pos) - 0)   < 30).
