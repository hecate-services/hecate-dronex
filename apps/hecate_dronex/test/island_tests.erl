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
