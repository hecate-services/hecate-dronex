%% @doc What one sensor reports, and what it refuses to report.
-module(ground_sensor_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).

%% A sensor at the arena floor, far from the ring, so a test can put a target at
%% an exact distance from it without the rest of the network interfering.
s(Id) -> #{id => Id, x => 1000 * ?M, y => 1000 * ?M, z => 0}.

truth(Id, Xm) -> #{id => Id, x => 1000 * ?M + Xm * ?M, y => 1000 * ?M, z => 0}.

seen(Id, Xm, Tick) -> ground_sensor:observe(truth(Id, Xm), s(one), #{tick => Tick}).

%% Over many ticks, how often a target at this distance is reported at all.
hits(Xm, Ticks) ->
    length([ok || T <- lists:seq(1, Ticks), {ok, _} <- [seen(bogey, Xm, T)]]).

%%==============================================================================
%% Range is a hard edge
%%==============================================================================

beyond_the_range_is_a_miss_on_every_tick_test() ->
    Beyond = (?SENSOR_RANGE div ?M) + 5,
    %% ⚠ NOT `USUALLY A MISS'. A sensor that occasionally saw past its own range
    %% would have no edge, and without an edge there are no corridors — which is
    %% to say no approach path, which is the only counterplay to a network this
    %% design offers. 400 ticks is enough that a one-in-a-thousand leak shows.
    ?assertEqual(0, hits(Beyond, 400)).

inside_the_range_it_reports_test() ->
    ?assert(hits(5, 200) > 0).

nearer_is_seen_more_often_than_further_test() ->
    Near = hits(10, 400),
    Far = hits((?SENSOR_RANGE div ?M) - 10, 400),
    ?assert(Near > Far),
    %% And the near rate is roughly the near probability, which is what makes the
    %% constant in the header mean what it says rather than merely exist.
    ?assert(Near > 400 * ?SENSOR_P_NEAR div 1000 * 85 div 100).

%%==============================================================================
%% ⚠ THE DRAW IS A PURE FUNCTION, WHICH IS WHY A RAID CAN BE REPLAYED
%%==============================================================================

the_same_roll_gives_the_same_answer_every_time_test() ->
    %% If this ever fails, an island cannot check the raid it flew into, and two
    %% machines running the same engagement diverge without either noticing.
    [?assertEqual(seen(bogey, 12, T), seen(bogey, 12, T)) || T <- lists:seq(1, 60)],
    ?assertEqual([seen(bogey, 12, T) || T <- lists:seq(1, 60)],
                 [seen(bogey, 12, T) || T <- lists:seq(1, 60)]).

different_drones_roll_differently_test() ->
    %% Otherwise every drone in a formation would be seen and missed in perfect
    %% unison, and a swarm would be one contact wearing twelve airframes.
    A = [seen(alpha, 12, T) || T <- lists:seq(1, 200)],
    B = [seen(bravo, 12, T) || T <- lists:seq(1, 200)],
    ?assertNotEqual(A, B).

different_ticks_roll_differently_test() ->
    Rolls = [seen(bogey, 12, T) || T <- lists:seq(1, 200)],
    ?assert(length(lists:usort(Rolls)) > 1).

%%==============================================================================
%% What a contact is, and is not
%%==============================================================================

a_contact_never_carries_the_drones_identity_test() ->
    {ok, C} = first_hit(3),
    %% ⚠ THE WHOLE REASON TRACKING IS A PROBLEM. The counter-UAS line's
    %% correlator built a track id by concatenating onto the drone's own
    %% self-reported identity, which works only against a target that announces
    %% itself. If an id ever appears in this map, association stops being
    %% position-based and the tracker silently becomes a lookup.
    ?assertEqual([confidence, sensor, tick, x, y, z], lists:sort(maps:keys(C))),
    ?assertEqual(one, maps:get(sensor, C)).

the_time_on_a_contact_is_the_tick_test() ->
    %% A wall clock here would make a fight unreplayable, which is I.12's lesson
    %% arriving from a different direction.
    {ok, C} = seen_at_some_tick(3),
    ?assert(is_integer(maps:get(tick, C))),
    ?assert(maps:get(tick, C) =< 400).

a_near_contact_is_nearly_exact_test() ->
    {ok, #{x := X}} = first_hit(1),
    ?assert(abs(X - (1000 * ?M + 1 * ?M)) < 2 * ?M).

a_far_contact_is_out_by_tens_of_metres_test() ->
    Edge = (?SENSOR_RANGE div ?M) - 5,
    Errors = [abs(X - (1000 * ?M + Edge * ?M))
              || T <- lists:seq(1, 400), {ok, #{x := X}} <- [seen(bogey, Edge, T)]],
    ?assert(Errors =/= []),
    %% Somewhere in 400 sightings the error is large. A single contact at the
    %% fringe is not a firing solution, which is what forces a track to be built
    %% rather than acted on.
    ?assert(lists:max(Errors) > 10 * ?M).

confidence_falls_with_range_test() ->
    {ok, #{confidence := Near}} = first_hit(1),
    {ok, #{confidence := Far}} = first_hit((?SENSOR_RANGE div ?M) - 10),
    ?assert(Near > Far).

first_hit(Xm) -> hd([R || T <- lists:seq(1, 400), {ok, _} = R <- [seen(bogey, Xm, T)]]).

seen_at_some_tick(Xm) -> first_hit(Xm).

%%==============================================================================
%% Placement
%%==============================================================================

the_network_is_a_ring_and_a_centre_test() ->
    Placed = ground_sensor:place(5),
    ?assertEqual(5, length(Placed)),
    ?assertEqual([centre, {ring, 1}, {ring, 2}, {ring, 3}, {ring, 4}],
                 [maps:get(id, S) || S <- Placed]).

placement_is_asked_of_the_physics_not_redeclared_test() ->
    #{arena_x := Ax, arena_y := Ay} = airspace:limits(),
    [#{x := Cx, y := Cy} | Ring] = ground_sensor:place(5),
    ?assertEqual(Ax div 2, Cx),
    ?assertEqual(Ay div 2, Cy),
    %% Every station stands inside the arena. A ring computed against a stale
    %% copy of the arena size would put sensors outside the volume they defend,
    %% and nothing else in the system would complain.
    [begin
         ?assert(X >= 0 andalso X =< Ax),
         ?assert(Y >= 0 andalso Y =< Ay)
     end || #{x := X, y := Y} <- Ring].

sensors_stand_on_the_ground_test() ->
    [?assertEqual(0, maps:get(z, S)) || S <- ground_sensor:place(5)].

the_count_is_physics_and_lands_in_the_fingerprint_test() ->
    %% ⚠ SO TWO ISLANDS WITH DIFFERENT NETWORKS REFUSE EACH OTHER. Sensor count
    %% changes who wins; a fingerprint that ignored it would let two engines that
    %% disagree about the world accept each other's raids and settle them on
    %% incomparable results.
    ?assertEqual(?SENSORS, maps:get(sensors, airspace:limits())),
    ?assert(maps:is_key(sensor_range, airspace:limits())).

%%==============================================================================
%% ⚠ GHOSTS
%%==============================================================================

the_network_sometimes_sees_things_that_are_not_there_test() ->
    Ghosts = lists:flatten([ground_sensor:ghosts(ground_sensor:place(5), T) || T <- lists:seq(1, 400)]),
    %% Without false alarms, any confirmation threshold above one is strictly
    %% worse than one: more evidence would mean later and never safer, and the
    %% number this phase exists to tune would decide nothing.
    ?assert(length(Ghosts) > 0).

ghosts_are_rare_enough_to_be_ghosts_test() ->
    Ghosts = lists:flatten([ground_sensor:ghosts(ground_sensor:place(5), T) || T <- lists:seq(1, 400)]),
    %% Five sensors, 400 ticks. A network mostly reporting fiction is not a
    %% network, and the tracker would confirm noise as fast as it confirms
    %% aircraft.
    ?assert(length(Ghosts) < 400).

a_ghost_is_indistinguishable_from_a_contact_test() ->
    [G | _] = lists:flatten([ground_sensor:ghosts(ground_sensor:place(5), T) || T <- lists:seq(1, 400)]),
    %% Same fields, same shape. A false alarm that could be told apart from a
    %% detection by inspecting it would make the threshold pointless: the
    %% tracker would simply filter on the tell.
    ?assertEqual([confidence, sensor, tick, x, y, z], lists:sort(maps:keys(G))).

ghosts_appear_inside_the_range_that_invented_them_test() ->
    Placed = ground_sensor:place(5),
    Byid = maps:from_list([{Id, S} || #{id := Id} = S <- Placed]),
    [begin
         #{x := Sx, y := Sy} = maps:get(Id, Byid),
         ?assert(fixed:mag3(Gx - Sx, Gy - Sy, 0) =< ?SENSOR_RANGE + 1)
     end
     || #{sensor := Id, x := Gx, y := Gy}
        <- lists:flatten([ground_sensor:ghosts(Placed, T) || T <- lists:seq(1, 200)])].

ghosts_are_deterministic_too_test() ->
    Placed = ground_sensor:place(5),
    ?assertEqual([ground_sensor:ghosts(Placed, T) || T <- lists:seq(1, 100)],
                 [ground_sensor:ghosts(Placed, T) || T <- lists:seq(1, 100)]).
