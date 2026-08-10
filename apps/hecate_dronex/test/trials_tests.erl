%% @doc The held-out ladder, and the guard that keeps it held out.
-module(trials_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

null_genome() ->
    {topology(), lists:duplicate(drone_genome:gene_count(topology()), 0)}.

%%==============================================================================
%% ⚠ THE GUARD. This is the whole reason the module exists.
%%==============================================================================

%% ⚠⚠ THE FIRST EXAM WAS HELD OUT BY ASSERTION IN FOUR DOCUMENTS AND BY NOTHING
%% IN THE CODE, AND IT LEAKED FOR MONTHS. `drone_drills.erl' said "nothing ever
%% trains against them", `benchmark.erl' was built on it, `CHARTER.md' promised "a
%% frozen benchmark it never trains against", `DESIGN_THE_ROSTER_AND_THE_RAID.md'
%% repeated it, and `REGISTER D.7' published the sentence "the population improved
%% against an exam it never trains on" as a finding. Meanwhile
%% `trainer:opponents/1' returned `drone_drills:kinds() ++ roster' and
%% `benchmark:rungs/0' returned that same list.
%%
%% A comment cannot fail. This can.
no_exam_rung_is_ever_an_opponent_the_trainer_breeds_against_test() ->
    Roster = roster:new(island, 8),
    Opponents = trainer:opponents(Roster),
    [?assertNot(lists:member(K, Opponents)) || K <- drone_trials:kinds()],
    %% And stated the other way round, so the day somebody adds a kind to the
    %% curriculum that happens to share a name, this fails rather than passing by
    %% coincidence.
    ?assertEqual([], [K || K <- drone_trials:kinds(),
                           lists:member(K, drone_drills:kinds())]).

%% The exam ladder and the curriculum ladder are different modules, and the
%% benchmark names which is which rather than leaving a caller to remember.
the_two_ladders_are_named_and_distinct_test() ->
    ?assertEqual(drone_drills, benchmark:curriculum_ladder()),
    ?assertEqual(drone_trials, benchmark:held_out_ladder()),
    ?assertNotEqual(benchmark:curriculum_ladder(), benchmark:held_out_ladder()).

%% ⚠ THE DEFAULT IS STILL THE CURRICULUM, so every caller that had one exam keeps
%% exactly the exam it had. The contaminated instrument is relabelled, never
%% silently swapped: a number that changes meaning without changing name is worse
%% than a number that is wrong.
the_default_ladder_is_unchanged_test() ->
    ?assertEqual(drone_drills:kinds(), benchmark:rungs()),
    ?assertEqual(drone_trials:kinds(), benchmark:rungs(drone_trials)).

%%==============================================================================
%% The rungs
%%==============================================================================

%% ⚠ THIS PINS STABILITY, NOT CORRECTNESS, AND SINCE 2026-08-09 THE DIFFERENCE
%% MATTERS. The order below was measured over 48 starts against five live
%% champions — circler 227, harrier 202, marksman 192, bruiser 185, swooper 139,
%% leader 130 out of 240 — under a guided weapon reaching 600 m and a start set
%% opening at 400 m. The weapon has reached 60 m and now reaches 120 m, the set
%% opens at 800 m, and those champions have been wiped, so the ORDER IS UNKNOWN.
%%
%% ⚠⚠ IT IS STILL ASSERTED, ON PURPOSE, SO THE LIST CANNOT DRIFT WHILE NOBODY IS
%% LOOKING. What this catches today is a silent reorder or a rung appearing and
%% disappearing. What it does NOT do any more is certify that the curve runs easy
%% to hard. Re-measure once a population exists that can tell rungs apart: a null
%% and five random controllers currently win 0 of 48 on every rung, so there is
%% nothing to grade with. `REGISTER D.4'.
there_are_six_held_out_rungs_in_a_provisional_order_test() ->
    ?assertEqual([circler, harrier, marksman, bruiser, swooper, leader],
                 drone_trials:kinds()),
    ?assertEqual(6, length(drone_trials:kinds())).

every_rung_describes_itself_test() ->
    [?assert(byte_size(drone_trials:describe(K)) > 0) || K <- drone_trials:kinds()].

%% ⚠ A TRIAL READS THE SAME SENSOR VECTOR AN EVOLVED CONTROLLER READS. Same
%% fairness property the curriculum drills carry: an opponent written against the
%% arena would see behind itself and past 600 m, and every exam number would be a
%% measurement against better eyes.
a_trial_is_blind_where_a_pilot_is_blind_test() ->
    ?assert(lists:member({act, 4}, drone_trials:module_info(exports))),
    ?assert(lists:member({act, 4}, drone_pilot:module_info(exports))).

%% ⚠⚠ EVERY RUNG SHOOTS AND EVERY RUNG CLOSES, which is what `D.16' says the
%% surviving deficit is against and is the entire premise of this ladder. The
%% curriculum's bottom half is unarmed on purpose; here an unarmed rung would be
%% a rung from the wrong ladder.
every_rung_shoots_test() ->
    [?assert(fires(K)) || K <- drone_trials:kinds()].

every_rung_closes_test() ->
    [?assert(closes(K)) || K <- drone_trials:kinds()].

fires(K) ->
    {I, _} = drone_trials:act(drone_trials:init(K), lone(), [close()], []),
    I#intent.release =:= 1 orelse I#intent.launch =:= 1.

%% Measured at range, where a closing rung must be commanding forward thrust.
%% `circler' is the exception BY DESIGN and closes only while outside its
%% standoff, which the contact here is.
closes(K) ->
    {I, _} = drone_trials:act(drone_trials:init(K), lone(), [far_off_axis()], []),
    I#intent.thrust_fwd > 0.

%%==============================================================================
%% One competence each, which is what makes the profile readable
%%==============================================================================

%% ⚠ THE CURRICULUM STEERS ONLY IN YAW, SO CLIMBING AWAY FROM IT WORKS. Every
%% rung of `drone_drills' commands exactly enough vertical thrust to hold its own
%% altitude. `bruiser' is the first opponent in this repository that follows.
the_bruiser_follows_in_the_vertical_and_the_chaser_does_not_test() ->
    #{gravity := G} = airspace:limits(),
    {B, _} = drone_trials:act(drone_trials:init(bruiser), lone(), [above()], []),
    {C, _} = drone_drills:act(drone_drills:init(chaser), lone(), [above()], []),
    ?assertEqual(G, C#intent.thrust_vert),
    ?assert(B#intent.thrust_vert > G).

%% ⚠ THE FIRST OPPONENT THAT DOES NOT TRAVEL ALONG ITS OWN NOSE. Nothing in
%% `drone_drills' ever commands lateral thrust, so a controller can assume an
%% opponent's velocity and its aim are the same line.
the_harrier_slips_sideways_and_nothing_in_the_curriculum_does_test() ->
    ?assert(lists:any(fun (N) -> lat_after(harrier, N) =/= 0 end, lists:seq(0, 90))),
    [?assertEqual(0, curriculum_lat_after(K, N))
     || K <- drone_drills:kinds(), N <- [0, 25, 60]].

%% Deterministic from its own counter, so an exam needs no clock and no
%% generator and two runs of it agree.
the_slip_reverses_on_a_period_test() ->
    Lats = [lat_after(harrier, N) || N <- lists:seq(0, 90)],
    ?assert(lists:max(Lats) > 0),
    ?assert(lists:min(Lats) < 0),
    ?assertEqual(Lats, [lat_after(harrier, N) || N <- lists:seq(0, 90)]).

lat_after(Kind, N) ->
    {I, _} = drone_trials:act({Kind, N, #{last_sin => 0.0, last_side => 0}},
                              lone(), [close()], []),
    I#intent.thrust_lat.

curriculum_lat_after(Kind, N) ->
    {I, _} = drone_drills:act({Kind, N}, lone(), [close()], []),
    I#intent.thrust_lat.

%% ⚠ IT BACKS OFF INSIDE ITS RANGE AND CLOSES OUTSIDE IT, so neither running away
%% nor charging changes the fight it offers. A controller that beat the chaser by
%% rushing it does not beat this.
the_circler_holds_the_range_it_chose_test() ->
    {Near, _} = drone_trials:act(drone_trials:init(circler), lone(), [close()], []),
    {Far, _} = drone_trials:act(drone_trials:init(circler), lone(), [far_off_axis()], []),
    ?assert(Near#intent.thrust_fwd < 0),
    ?assert(Far#intent.thrust_fwd > 0).

%% Above while far, diving once inside. The altitude advantage is taken before it
%% commits rather than fought for afterwards.
the_swooper_climbs_before_it_commits_test() ->
    {Far, _} = drone_trials:act(drone_trials:init(swooper), lone(), [far_off_axis()], []),
    {Near, _} = drone_trials:act(drone_trials:init(swooper), lone(), [close()], []),
    ?assert(Far#intent.thrust_vert > Near#intent.thrust_vert).

%% ⚠⚠ THE LEAD CHANGES WHEN THE TURN REVERSES, NEVER HOW FAST IT TURNS. Turning
%% is bang-bang at `max_yaw_rate' for every rung on both ladders, so a lead that
%% did not flip a sign would be a rung that silently degenerates into the chaser
%% it is supposed to improve on. Here the contact has drifted across the nose:
%% remembering the drift is the only way to know a reversal is coming.
the_leader_reverses_before_the_contact_has_crossed_test() ->
    Drifted = {leader, 1, #{last_sin => 0.4, last_side => 1}},
    Blind = {leader, 1, #{last_sin => 0.0, last_side => 0}},
    {L, _} = drone_trials:act(Drifted, lone(), [barely_left()], []),
    {N, _} = drone_trials:act(Blind, lone(), [barely_left()], []),
    ?assertNotEqual(L#intent.yaw_rate, N#intent.yaw_rate).

%% ⚠⚠⚠ THE MAGAZINE IS FOUR FOR A WHOLE ENGAGEMENT AND TWO HITS KILL, so what a
%% controller spends its interceptors on decides the fight. Every other rung on
%% both ladders launches at `bearing_cos > 0.9', a 26 degree cone at any range
%% out to 600 m. `marksman' is the only opponent in this repository that holds
%% fire, and it is the only added competence here that is a firing policy rather
%% than a movement one.
the_marksman_refuses_a_shot_the_chaser_takes_test() ->
    Loose = wide_but_visible(),
    {M, _} = drone_trials:act(drone_trials:init(marksman), lone(), [Loose], []),
    {C, _} = drone_drills:act(drone_drills:init(chaser), lone(), [Loose], []),
    ?assertEqual(1, C#intent.launch),
    ?assertEqual(0, M#intent.launch),
    ?assertEqual(0, M#intent.release).

%% And it does take the shot that is worth taking, so the rung is discipline
%% rather than a weapon that does not work.
the_marksman_takes_the_shot_it_was_waiting_for_test() ->
    {M, _} = drone_trials:act(drone_trials:init(marksman), lone(), [dead_ahead()], []),
    ?assertEqual(1, M#intent.launch).

%% ⚠ EVERY RUNG HOLDS STATION WITH AN EMPTY CONE, exactly as the curriculum does,
%% so no rung's difficulty depends on where it happened to drift to.
%%
%% ⚠⚠ AND A SEVENTH RUNG THAT DID NOT WAS MEASURED OUT. `hunter' came looking
%% instead of holding station, which is the one demand `drone_drills' cannot
%% make. Over 48 starts against five champions it returned the same wins as
%% `bruiser', champion for champion, down to the single draw: a champion bred to
%% fight never breaks contact, so the difference never fired. `REGISTER D.4' and
%% `I.23'.
every_rung_holds_station_when_blind_test() ->
    #{gravity := G} = airspace:limits(),
    [begin
         {I, _} = drone_trials:act(drone_trials:init(K), lone(), [], []),
         ?assertEqual(G, I#intent.thrust_vert),
         ?assertEqual(0, I#intent.thrust_fwd)
     end || K <- drone_trials:kinds()].

%%==============================================================================
%% Sitting it
%%==============================================================================

the_held_out_profile_is_a_curve_and_never_a_number_test() ->
    {ok, P} = benchmark:sit(null_genome(), #{starts => 2, ladder => drone_trials}),
    ?assertEqual([draws, losses, rungs, starts, wins], lists:sort(maps:keys(P))),
    ?assertNot(maps:is_key(score, P)),
    ?assertNot(maps:is_key(total, P)),
    ?assertEqual(drone_trials:kinds(), maps:get(rungs, P)).

%% ⚠ THE PROFILE CARRIES ITS OWN RUNG NAMES, so which ladder produced a reading
%% is a property of the reading. Two exams publishing bare vectors would be two
%% numbers a reader has to keep straight by memory, and that is exactly the kind
%% of bookkeeping that produced `I.22'.
a_profile_names_the_ladder_that_produced_it_test() ->
    {ok, Curriculum} = benchmark:sit(null_genome(), #{starts => 1}),
    {ok, HeldOut} = benchmark:sit(null_genome(), #{starts => 1, ladder => drone_trials}),
    ?assertNotEqual(maps:get(rungs, Curriculum), maps:get(rungs, HeldOut)).

%%==============================================================================
%% On the wire
%%==============================================================================

%% ⚠ BESIDE THE CURRICULUM AND NEVER INSTEAD OF IT. Replacing the `benchmark_*'
%% keys would have silently changed what every historical reading meant, with
%% nothing marking the discontinuity, which is worse than publishing a number
%% that is wrong.
both_exams_ride_the_fact_under_their_own_keys_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertEqual(drone_drills:kinds(), maps:get(benchmark_rungs, Fact)),
    ?assertEqual(drone_trials:kinds(), maps:get(trials_rungs, Fact)),
    ?assertNotEqual(maps:get(benchmark_rungs, Fact), maps:get(trials_rungs, Fact)),
    [?assert(maps:is_key(K, Fact))
     || K <- [trials_wins, trials_draws, trials_losses, trials_starts]].

%% CHARTER.md rule 4 for the new vector too: an island that has not sat the
%% held-out exam and one that sat it and lost everything must not look the same.
an_unsat_held_out_exam_publishes_zeros_and_says_zero_starts_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertEqual(0, maps:get(trials_starts, Fact)),
    ?assertEqual(lists:duplicate(6, 0), maps:get(trials_wins, Fact)).

%% ⚠ THE FACT VERSION MOVED, because a reader keying on it must be able to tell
%% an island that publishes the held-out exam from one that does not. Islands
%% roll one at a time, so during any deploy both are on the wire at once.
the_fact_version_says_the_held_out_exam_is_there_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assert(maps:get(fact_version, Fact) >= 5).

runtime() ->
    #{writer => #{written => 0, failed => 0, dropped => 0},
      reachable => #{open => false, listening => false, advertising => false}}.

%% ⚠ THE IDENTITY IS READ FROM A DATA DIR, so a test must give it one or it
%% writes into whatever the working directory happens to be.
with_data_dir(F) ->
    Dir = "/tmp/dronex_trials_tests",
    ok = filelib:ensure_path(Dir),
    Was = application:get_env(hecate_dronex, data_dir),
    application:set_env(hecate_dronex, data_dir, Dir),
    try F() after restored(Was) end.

restored(undefined) -> application:unset_env(hecate_dronex, data_dir);
restored({ok, V}) -> application:set_env(hecate_dronex, data_dir, V).

an_unsat_held_out_exam_is_zeros_with_zero_starts_test() ->
    P = benchmark:empty(drone_trials),
    ?assertEqual(0, maps:get(starts, P)),
    ?assertEqual(drone_trials:kinds(), maps:get(rungs, P)),
    ?assertEqual(lists:duplicate(6, 0), maps:get(wins, P)).

%%==============================================================================
%% Fixtures
%%==============================================================================

lone() ->
    hd(airspace:drones(airspace:new([{a, attacker, 500 * 20480, 500 * 20480,
                                      100 * 20480, 0}]))).

close() ->
    hd(airspace:drones(airspace:new([{b, defender, 505 * 20480, 500 * 20480,
                                      100 * 20480, 0}]))).

%% ⚠ ABOVE, BUT MOSTLY AHEAD, AND THE FIRST VERSION OF THIS FIXTURE WAS NEITHER.
%% It put the contact 10 m ahead and 60 m up, which is 80 degrees off the nose and
%% therefore OUTSIDE the 120 degree cone: invisible, so every rung correctly held
%% station and the test read as "the bruiser does not climb". 60 m ahead and 30 m
%% up is 27 degrees, comfortably inside, and the vertical offset is still the only
%% interesting difference.
above() ->
    hd(airspace:drones(airspace:new([{b, defender, 560 * 20480, 500 * 20480,
                                      130 * 20480, 0}]))).

%% Beyond the circler's standoff, off the nose so a turn is not a no-op. About
%% 126 m out, which cleared the standoff when it was a flat 90 m, cleared it at
%% three quarters of a 60 m weapon, and clears it at three quarters of the 120 m
%% one — 90 m — by the narrowest margin it has ever had. A longer reach eats this
%% fixture's headroom, so a further increase needs this distance moved out.
far_off_axis() ->
    hd(airspace:drones(airspace:new([{b, defender, 620 * 20480, 540 * 20480,
                                      100 * 20480, 0}]))).

%% Just left of the nose: a bearing small enough that a remembered drift can
%% carry the lead across zero and reverse the turn.
barely_left() ->
    hd(airspace:drones(airspace:new([{b, defender, 600 * 20480, 501 * 20480,
                                      100 * 20480, 0}]))).

%% Inside the chaser's 26 degree gate and outside the marksman's 11 degree one:
%% 45 m ahead and 14 m off, which is about 17 degrees.
%%
%% ⚠ 45 m, AND IT WAS 100 m UNTIL 2026-08-09. The guided weapon reached 600 m and
%% was cut to 60 m, so both rungs refused a 100 m shot and the fixture stopped
%% separating them: the test went red saying the CHASER would not fire, which was
%% correct and was not what it is here to check. Any distance inside the envelope
%% works; this one keeps the same angle the comment always claimed.
wide_but_visible() ->
    hd(airspace:drones(airspace:new([{b, defender, 545 * 20480, 514 * 20480,
                                      100 * 20480, 0}]))).

%% Straight ahead at 45 m: inside both gates and inside the marksman's range
%% band, so it is the shot the discipline was saving for.
dead_ahead() ->
    hd(airspace:drones(airspace:new([{b, defender, 545 * 20480, 500 * 20480,
                                      100 * 20480, 0}]))).

%% ⚠ THE CIRCLER'S STANDOFF IS BOUNDED, NOT PINNED, WHICH IS WHY THIS CHECKS THE
%% TWO CLAIMS ITS COMMENT MAKES RATHER THAN A NUMBER. It has to sit inside the
%% guided weapon, or the rung holds station where it can never shoot and quietly
%% becomes a hoverer, and it has to sit well outside the roughly 15 m where an
%% unguided release works, or it is a chaser with extra steps. Both were true of
%% the literal 0.15 until the weapon shrank on 2026-08-09, and the first stopped
%% being true the same hour without anything failing.
the_circlers_standoff_stays_inside_its_own_weapon_test() ->
    Reach = drone_senses:reach_fraction(),
    Standoff = reported_standoff(),
    ?assert(Standoff < Reach),
    ?assert(Standoff * drone_senses:range() > 30 * 20480).

%% Read back through the behaviour rather than by exporting the constant: the
%% range at which the circler stops closing IS its standoff.
reported_standoff() ->
    Ranges = [R / 1000 || R <- lists:seq(1, 999)],
    Closing = [R || R <- Ranges, closes_at(R)],
    lists:min(Closing).

closes_at(R) ->
    D = hd(airspace:drones(airspace:new(
            [{b, defender, trunc(500 * 20480 + R * drone_senses:range()),
              500 * 20480, 100 * 20480, 0}]))),
    {I, _} = drone_trials:act(drone_trials:init(circler), lone(), [D], []),
    I#intent.thrust_fwd > 0.
