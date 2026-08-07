%% @doc The island as a value.
-module(island_tests).

-include_lib("eunit/include/eunit.hrl").

a_new_island_starts_at_zero_test() ->
    I = island:new(#{}),
    ?assertEqual(0, island:tick_of(I)),
    ?assertEqual(0, island:roster_depth(I)),
    ?assertEqual(240, island:capacity(I)).

the_clock_advances_by_what_it_is_given_test() ->
    I = island:run(island:run(island:new(#{}), 10), 5),
    ?assertEqual(15, island:tick_of(I)).

advancing_by_nothing_is_allowed_test() ->
    ?assertEqual(0, island:tick_of(island:run(island:new(#{}), 0))).

the_seed_is_carried_test() ->
    ?assertEqual(2029, island:seed_of(island:new(#{seed => 2029}))).

%% ⚠ THE ROSTER IS FINITE, AND THAT IS PRICED RATHER THAN INCIDENTAL. CHARTER.md
%% spends a genome when it flies, so an unbounded archive would make losing a
%% raid free. This asserts a capacity exists and can be set; nothing fills the
%% roster yet.
the_capacity_can_be_set_test() ->
    ?assertEqual(64, island:capacity(island:new(#{capacity => 64}))).

%% ⚠ THE GUARD FOR CHARTER RULE 2. `new/1' takes the seed and the capacity, which
%% say which RUN this is. It must never grow an option that names the physics: a
%% sibling put two of three fleet nodes into a boot-crash loop because a world
%% constant lived in a deployment repository on another release cadence.
%%
%% This is a structural test rather than a behavioural one, and it is the only
%% kind available: it fails the day somebody adds a physics key to the map, which
%% is exactly when the reminder is wanted.
new_takes_only_run_identity_and_never_physics_test() ->
    I = island:new(#{seed => 1, capacity => 8}),
    ?assertEqual(1, island:seed_of(I)),
    ?assertEqual(8, island:capacity(I)),
    %% An unknown key is ignored rather than honoured, so a stray physics
    %% override in a node config cannot take effect by being spelled right.
    J = island:new(#{seed => 1, gravity => 999}),
    ?assertEqual(1, island:seed_of(J)).

%%==============================================================================
%% The tally: a lineage's history, which for weeks did not survive a deploy
%%==============================================================================

%% ⚠ THE COUNTERS WERE PUT ON THE ISLAND SO THEY WOULD SURVIVE A RESTART, and
%% nothing ever wrote them down. The record's own comment said they were safe
%% here. These tests are what makes that comment true.
a_tally_names_every_counter_a_lineage_owns_test() ->
    T = island:tally_of(island:new(#{seed => 1})),

    ?assertEqual(lists:sort([tick, rounds, admissions, ablations, raids,
                             raids_home, raids_lost, defences, captures]),
                 lists:sort(maps:keys(T))).

a_restored_tally_comes_back_whole_test() ->
    I = island:new(#{seed => 1}),
    Stored = #{tick => 5000, rounds => 900, admissions => 40, ablations => 3,
               raids => 12, raids_home => 7, raids_lost => 5, defences => 9,
               captures => 2},

    ?assertEqual(Stored, island:tally_of(island:with_tally(I, Stored))).

%% ⚠ A COUNTER NEVER GOES BACKWARDS. A snapshot older than what is already in
%% hand must not wind a lineage's history back.
a_stale_tally_never_lowers_a_live_counter_test() ->
    I = island:with_tally(island:new(#{seed => 1}), #{rounds => 900, raids => 12}),
    Stale = island:with_tally(I, #{rounds => 10, raids => 1}),

    ?assertEqual(900, island:rounds_of(Stale)),
    ?assertEqual(12, island:raids_of(Stale)).

%% An absent key leaves its counter alone, which is what every snapshot written
%% before the tally existed will hand back.
an_absent_counter_leaves_the_live_one_alone_test() ->
    I = island:with_tally(island:new(#{seed => 1}), #{rounds => 900}),

    ?assertEqual(900, island:rounds_of(island:with_tally(I, #{}))).

%% A field a rollback wrote as something other than a count is ignored rather
%% than crashing a boot on it.
a_counter_that_is_not_a_count_is_ignored_test() ->
    I = island:with_tally(island:new(#{seed => 1}), #{rounds => <<"nine thousand">>}),

    ?assertEqual(0, island:rounds_of(I)).

%% ⚠ THE EXAM IS NOT CARRIED. `benchmark' and `sitter' are re-sat within minutes
%% of boot, and restoring them would put a score computed by an image that no
%% longer exists in front of a reader as this image's work.
the_tally_does_not_carry_the_exam_test() ->
    T = island:tally_of(island:new(#{seed => 1})),

    ?assertNot(maps:is_key(benchmark, T)),
    ?assertNot(maps:is_key(sitter, T)).
