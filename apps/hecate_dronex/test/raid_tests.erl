%% @doc The price of a raid, and the thing the defender gets for paying it.
-module(raid_tests).

-include_lib("eunit/include/eunit.hrl").

seeded(N) -> seeded(N, {11, 22, 33}).

%% ⚠ TWO ISLANDS ARE TWO RUNS, AND SEEDING THEM ALIKE HID A PASS. The first
%% version of this file seeded both from one seed, so `their' genomes were
%% literally the same objects as mine, `absorb/3' correctly kept none of them,
%% and the test failed for a reason that had nothing to do with what it was
%% asserting. A foreign island has to be foreign.
seeded(N, Seed) ->
    S0 = rand:seed_s(exsss, Seed),
    trainer:seed_roster(roster:new(probe, 240), N, S0).

entry_of(R, Id) -> hd([E || E <- roster:entries(R), roster:entry_id(E) =:= Id]).

ids(Es) -> lists:sort([roster:entry_id(E) || E <- Es]).

%%==============================================================================
%% ⚠ THE PRICE
%%==============================================================================

%% A genome is spent when it flies. Removed, not copied and not flagged: a flag
%% would leave it available to the trainer as a parent and to a defender as an
%% opponent while it is supposedly airborne, so an island would field the same
%% controller in two places and the roster's finiteness would be decorative.
a_sortie_leaves_the_roster_test() ->
    {R, S} = seeded(100),
    {Party, R1, _S1} = raid:sortie(R, S, 6),
    ?assertEqual(6, length(Party)),
    ?assertEqual(roster:depth(R) - 6, roster:depth(R1)),
    [?assertNot(roster:has(R1, Id)) || Id <- ids(Party)].

%% ⚠ THE FLOOR STOPS AN ISLAND RAIDING ITSELF TO EXTINCTION, the local form of
%% what killed every configuration in insight 062. Below it, nobody leaves.
an_island_below_the_floor_stays_home_test() ->
    {R, S} = seeded(raid:floor_of()),
    {Party, R1, _S1} = raid:sortie(R, S, 6),
    ?assertEqual([], Party),
    ?assertEqual(roster:depth(R), roster:depth(R1)).

%% And the boundary is the floor itself rather than near it: leaving must not be
%% allowed to take the roster below it.
the_floor_is_a_floor_and_not_a_suggestion_test() ->
    {R, S} = seeded(raid:floor_of() + raid:party()),
    {Party, R1, _} = raid:sortie(R, S, raid:party()),
    ?assertEqual(raid:party(), length(Party)),
    ?assertEqual(raid:floor_of(), roster:depth(R1)),
    {None, _R2, _} = raid:sortie(R1, S, 1),
    ?assertEqual([], None).

%% A sortie is counted on the roster that stays behind, so the record of having
%% attacked survives the party not coming back.
a_sortie_is_counted_even_when_nobody_returns_test() ->
    {R, S} = seeded(100),
    {Party, R1, _} = raid:sortie(R, S, 3),
    {R2, Home, Lost} = raid:settle(R1, Party, []),
    ?assertEqual({0, 3}, {Home, Lost}),
    ?assertEqual(roster:depth(R1), roster:depth(R2)).

%%==============================================================================
%% Coming home
%%==============================================================================

survivors_return_and_the_dead_do_not_test() ->
    {R, S} = seeded(100),
    {Party, R1, _} = raid:sortie(R, S, 4),
    [A, B, C, D] = Party,
    Fates = [{roster:entry_id(A), survived}, {roster:entry_id(B), lost},
             {roster:entry_id(C), survived}, {roster:entry_id(D), lost}],
    {R2, Home, Lost} = raid:settle(R1, Party, Fates),
    ?assertEqual({2, 2}, {Home, Lost}),
    ?assert(roster:has(R2, roster:entry_id(A))),
    ?assert(roster:has(R2, roster:entry_id(C))),
    ?assertNot(roster:has(R2, roster:entry_id(B))),
    ?assertNot(roster:has(R2, roster:entry_id(D))).

%%==============================================================================
%% ⚠ WHAT THE DEFENDER GETS, WHICH IS THE POINT
%%==============================================================================

%% The attacker's genomes enter the roster, and `trainer:opponents/1' is every
%% roster entry, so they are in the opponent set from that moment. This is the
%% charter's one idea in mechanical form: a raid moves OPPONENTS, never fitness.
a_defender_keeps_what_attacked_it_test() ->
    {Mine, _S} = seeded(20),
    {Theirs, _S1} = seeded(3, {44, 55, 66}),
    Foreign = [{roster:entry_id(E), roster:entry_genome(E)} || E <- roster:entries(Theirs)],
    Meta = #{from => <<"them">>, raid => <<"raid-1">>, tick => 7},
    Kept = raid:absorb(Mine, Foreign, Meta),

    ?assertEqual(roster:depth(Mine) + 3, roster:depth(Kept)),
    [?assert(roster:has(Kept, Id)) || {Id, _G} <- Foreign],
    %% They are opponents now, which is the whole mechanism.
    Opponents = trainer:opponents(Kept),
    [?assert(lists:member(Id, Opponents)) || {Id, _G} <- Foreign].

%% ⚠ FOREIGN FITNESS IS NOT INHERITED. It was measured against somebody else's
%% opponent set and means nothing here. A captured genome enters as an OPPONENT
%% and earns a local number only if the local trainer ever sits it.
a_captured_genome_arrives_with_no_fitness_and_a_named_origin_test() ->
    {Mine, _S} = seeded(20),
    {Theirs, _} = seeded(1, {44, 55, 66}),
    [E] = roster:entries(Theirs),
    Id = roster:entry_id(E),
    Kept = raid:absorb(Mine, [{Id, roster:entry_genome(E)}],
                       #{from => <<"them">>, raid => <<"r1">>, tick => 7}),
    Entry = entry_of(Kept, Id),
    ?assertEqual(0, roster:entry_fitness(Entry)),
    ?assertEqual({captured, <<"them">>, <<"r1">>}, roster:entry_origin(Entry)).

%% Raided twice by the same swarm is not held twice, and re-admitting would reset
%% whatever it has since earned here.
absorbing_the_same_genome_twice_changes_nothing_test() ->
    {Mine, _S} = seeded(20),
    {Theirs, _} = seeded(2, {44, 55, 66}),
    Foreign = [{roster:entry_id(E), roster:entry_genome(E)} || E <- roster:entries(Theirs)],
    Meta = #{from => <<"them">>, raid => <<"r1">>, tick => 7},
    Once = raid:absorb(Mine, Foreign, Meta),
    Twice = raid:absorb(Once, Foreign, Meta#{raid => <<"r2">>}),
    ?assertEqual(roster:depth(Once), roster:depth(Twice)).

%%==============================================================================
%% Whom to attack
%%==============================================================================

%% There is no directory. An island that is silent is not attacked, and that is a
%% consequence of the public realm being the only place islands become visible to
%% each other rather than a protection anybody designed.
a_target_is_someone_else_who_has_been_heard_test() ->
    S = seed(),
    ?assertMatch({{ok, <<"b">>}, _}, raid:target([<<"a">>, <<"b">>], <<"a">>, S)),
    ?assertMatch({none, _}, raid:target([<<"a">>], <<"a">>, S)),
    ?assertMatch({none, _}, raid:target([], <<"a">>, S)).

seed() -> rand:seed_s(exsss, {1, 2, 3}).

%% Draw `N' targets, threading the generator the way the island does.
picks(Heard, Self, N) ->
    {Picks, _S} =
        lists:foldl(fun (_, {Acc, S}) ->
                        {{ok, T}, S1} = raid:target(Heard, Self, S),
                        {[T | Acc], S1}
                    end, {[], seed()}, lists:seq(1, N)),
        Picks.

%% ⚠⚠ THE TEST THAT WOULD HAVE CAUGHT THE ARCHIPELAGO COLLAPSING TO FOUR EDGES.
%%
%% `chosen/1' was `hd/1', and the list it was handed comes from
%% `maps:to_list/1' on a flatmap, which yields keys in SORTED order. So the old
%% code answers `<<"a">>' three hundred times out of three hundred and this
%% assertion fails on its first clause.
%%
%% Written as a spread and not as "is it random", because the defect was never
%% that the choice was predictable — it was that two of three candidates were
%% UNREACHABLE. On the fleet that meant beam03 was raided three times where its
%% neighbours were raided four hundred and eighty, while every admission filter
%% said it was a perfectly good target.
a_target_is_drawn_so_every_candidate_is_reachable_test() ->
    Heard = [<<"a">>, <<"b">>, <<"c">>],
    Picks = picks(Heard, <<"self">>, 300),

    ?assertEqual([<<"a">>, <<"b">>, <<"c">>], lists:usort(Picks)),

    %% and none of them is a rounding error: at 300 draws over 3 candidates,
    %% fewer than 50 is far outside anything a fair draw produces.
    lists:foreach(fun (C) ->
                      ?assert(length([X || X <- Picks, X =:= C]) > 50)
                  end, Heard).

%% ⚠ THE SELF-EXCLUSION MUST SURVIVE THE DRAW. An island that could draw itself
%% would raid its own procedure, and the call would answer.
a_target_is_never_oneself_however_often_it_is_drawn_test() ->
    Picks = picks([<<"a">>, <<"self">>, <<"c">>], <<"self">>, 200),
    ?assertEqual([<<"a">>, <<"c">>], lists:usort(Picks)).

%% Register `D.5': a run is a pure function of its seed, and whom an island chose
%% to attack is part of the run. A process-global draw would pass every other
%% test in this file and fail this one.
the_draw_is_reproducible_from_its_seed_test() ->
    ?assertEqual(picks([<<"a">>, <<"b">>, <<"c">>], <<"self">>, 50),
                 picks([<<"a">>, <<"b">>, <<"c">>], <<"self">>, 50)).

%% The caller's bound must exceed the callee's, or a slow-but-living defender
%% accepts and fights a party the attacker has already taken back.
the_handshake_timeouts_are_ordered_test() ->
    ?assert(dronex_raid:call_timeout_ms() > dronex_raid:muster_timeout_ms()),
    %% and both are a handshake's length, not an engagement's. The old value was
    %% 120000 with a comment about the callee fighting.
    ?assert(dronex_raid:call_timeout_ms() =< 30000).
