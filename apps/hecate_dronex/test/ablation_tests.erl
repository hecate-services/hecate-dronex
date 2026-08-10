%% @doc The instrument that says whether the channel is load-bearing, and the
%% probes that say whether the instrument can tell.
-module(ablation_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

genomes() ->
    S0 = rand:seed_s(exsss, {7, 7, 7}),
    {G1, S1} = breed:random(S0),
    {G2, _S2} = breed:random(S1),
    {G1, G2}.

fights(N) ->
    {G1, G2} = genomes(),
    [fight(G1, G2, I) || I <- lists:seq(0, N - 1)].

fight(G1, G2, I) ->
    Placed = drone_starts:place(2, 2, I),
    Cs = maps:from_list([{Id, ctrl(Side, G1, G2)} || {Id, Side, _, _, _, _} <- Placed]),
    {airspace:new(Placed), Cs}.

ctrl(attacker, G1, _G2) -> element(2, engagement:controller(G1));
ctrl(defender, _G1, G2) -> element(2, engagement:controller(G2)).

drill_fights(N) ->
    [drill_fight(I) || I <- lists:seq(0, N - 1)].

drill_fight(I) ->
    Placed = drone_starts:place(1, 1, I),
    Cs = maps:from_list([{Id, {drill, drone_drills, drone_drills:init(sniper)}}
                         || {Id, _Side, _, _, _, _} <- Placed]),
    {airspace:new(Placed), Cs}.

%%==============================================================================
%% ⚠ CAN THE INSTRUMENT TELL AT ALL
%%==============================================================================

%% ⚠ THE PROBE THAT WOULD HAVE CAUGHT THE MISTAKE THAT ACTUALLY HAPPENED. During
%% item 6 `radio.erl' was written into a directory that did not exist, so it was
%% never on disk, and everything downstream compiled cleanly BECAUSE it was
%% missing. A delta of zero from a mute that reaches nothing is indistinguishable
%% from a delta of zero from a channel nobody uses.
%%
%% This asserts the weaker but checkable thing: with the attacker silenced, the
%% fight RUNS DIFFERENTLY. It does not assert that it runs better.
the_mute_reaches_the_engine_test_() ->
    {timeout, 60, fun () ->
        Fs = fights(8),
        Base = [maps:get(ticks, engagement:run(A, C)) || {A, C} <- Fs],
        Muted = [maps:get(ticks, engagement:run(A, C, #{mute => #{attacker => all}}))
                 || {A, C} <- Fs],
        ?assertNotEqual(Base, Muted)
    end}.

%% And the two sides are separable: silencing the defender is not the same run as
%% silencing the attacker. A global mute would make these identical, and a
%% self-play delta would then cancel to zero however much the channel was worth.
%%
%% ⚠ EIGHT FIGHTS, NOT ONE, AND THE REASON IS THAT ONE WAS A COIN TOSS. This drew
%% a single fight and asserted the two tick counts differed. Two runs of the same
%% geometry CAN end on the same tick for reasons that have nothing to do with the
%% radio, so the test was passing on the draw rather than on the property, and it
%% went red on 2026-08-10 when `breed:random/1` changed which genomes a seed
%% produces. The engine was not touched by that change and is not what failed.
%%
%% Comparing the two SEQUENCES keeps the intent exactly and removes the
%% sensitivity: if muting the attacker and muting the defender were the same
%% operation, all eight pairs would agree, and a single coincidence no longer
%% decides the verdict. Same shape as the sibling test above, which already ran
%% over eight and never had this problem.
the_two_sides_mute_independently_test_() ->
    {timeout, 60, fun () ->
        Fs = fights(8),
        Att = [maps:get(ticks, engagement:run(A, C, #{mute => #{attacker => all}}))
               || {A, C} <- Fs],
        Def = [maps:get(ticks, engagement:run(A, C, #{mute => #{defender => all}}))
               || {A, C} <- Fs],
        ?assertNotEqual(Att, Def)
    end}.

%%==============================================================================
%% The three numbers
%%==============================================================================

%% ⚠ THE LADDER IS SILENT, SO AN ABLATION AGAINST IT IS VOID. Scripted drills
%% never transmit, so a delta measured there says nothing about coordination and
%% must not be reported as if it did. Charter rule 4: the null and the
%% never-exercised have to look different, and `void' is how.
an_ablation_over_silent_drills_is_void_test_() ->
    {timeout, 60, fun () ->
        R = ablation:measure(drill_fights(4)),
        ?assertEqual(0, maps:get(volume, R)),
        ?assert(maps:get(void, R)),
        ?assertEqual(#{channel => [0, 0, 0, 0], mean => 0}, maps:get(entropy, R)),
        %% And the delta really is zero there, which is what makes `void' load
        %% bearing rather than decorative.
        ?assertEqual(0, maps:get(air, maps:get(delta, R)))
    end}.

%% Untrained controllers transmit, because a random net drives every output.
%% Volume and entropy are therefore both positive while the delta is whatever it
%% is, which is exactly the state the three numbers exist to distinguish: driven,
%% varied, and depended on by nothing.
untrained_controllers_are_noisy_not_silent_test_() ->
    {timeout, 60, fun () ->
        R = ablation:measure(fights(6)),
        ?assertNot(maps:get(void, R)),
        ?assert(maps:get(volume, R) > 0),
        #{mean := Mean, channel := Per} = maps:get(entropy, R),
        ?assert(Mean > 0),
        ?assertEqual(4, length(Per)),
        %% Under the stated binning, and stated so the ceiling is visible.
        ?assert(lists:max(Per) =< ablation:max_entropy()),
        ?assertEqual(4000, ablation:max_entropy()),
        ?assertEqual(16, ablation:buckets())
    end}.

%% ⚠ THE ITEM 8 TRIPWIRE. The ground bank has no transmitter until the static
%% defence lands, so muting it is a no-op TODAY and its delta must be zero. When
%% item 8 makes this test fail, that failure is the finding.
the_ground_arm_is_a_no_op_until_the_static_defence_transmits_test_() ->
    {timeout, 60, fun () ->
        R = ablation:measure(fights(6)),
        ?assertEqual(maps:get(baseline, R), maps:get(ground, maps:get(muted, R))),
        ?assertEqual(0, maps:get(ground, maps:get(delta, R)))
    end}.

%%==============================================================================
%% Degenerate input
%%==============================================================================

%% No fights is void with a zero exercise count, not a zero delta wearing a
%% finding's clothes.
nothing_measured_is_void_test() ->
    R = ablation:measure([]),
    ?assertEqual(0, maps:get(engagements, R)),
    ?assert(maps:get(void, R)),
    ?assertEqual(0, maps:get(all, maps:get(delta, R))).

the_arms_are_the_three_the_design_names_test() ->
    ?assertEqual([air, ground, all], ablation:arms()).
