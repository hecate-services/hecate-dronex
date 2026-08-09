%% @doc The roster, variation, and the trainer's one round.
-module(roster_tests).

-include_lib("eunit/include/eunit.hrl").

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

%% Genomes that differ only in one gene, so ids differ and behaviour barely does.
genome(N) ->
    Count = drone_genome:gene_count(topology()),
    {topology(), [N | lists:duplicate(Count - 1, 0)]}.

entry(N, Fitness) ->
    roster:entry(genome(N), #{fitness => Fitness, generation => N,
                              origin => {bred, test}}).

full(Capacity) ->
    lists:foldl(fun (N, R) -> put_in(R, entry(N, N)) end,
                roster:new(test, Capacity), lists:seq(1, Capacity)).

put_in(R, E) -> taken(roster:admit(R, E), R).

taken({admitted, R}, _Was) -> R;
taken({refused, _Why}, Was) -> Was.

seeded(N) -> rand:seed_s(exsss, {N, N, N}).

%%==============================================================================
%% The roster
%%==============================================================================

a_new_roster_is_empty_test() ->
    R = roster:new(test, 8),
    ?assertEqual(0, roster:depth(R)),
    ?assertEqual(8, roster:capacity(R)),
    ?assertEqual(undefined, roster:best(R)),
    ?assertEqual(undefined, roster:worst(R)).

admitting_grows_it_test() ->
    {admitted, R} = roster:admit(roster:new(test, 8), entry(1, 10)),
    ?assertEqual(1, roster:depth(R)).

%% ⚠ THE ID IS THE CONTENT HASH, SO TWO IDENTICAL CONTROLLERS ARE ONE CONTROLLER.
%% Admitting both would let a lineage inflate its own numbers by rediscovering
%% itself, and every count over the roster would stop meaning what it says.
a_duplicate_is_refused_test() ->
    {admitted, R} = roster:admit(roster:new(test, 8), entry(1, 10)),
    ?assertEqual({refused, already_held}, roster:admit(R, entry(1, 99))).

best_and_worst_are_by_fitness_test() ->
    R = full(5),
    ?assertEqual(5, roster:entry_fitness(roster:best(R))),
    ?assertEqual(1, roster:entry_fitness(roster:worst(R))).

%% ⚠ TIES BREAK ON THE ID, NOT ON MAP ORDER. Map iteration order is not stable
%% across nodes or releases, so two islands holding identical rosters could
%% disagree about which entry is worst and evict different controllers.
ties_break_deterministically_test() ->
    R = lists:foldl(fun (N, Acc) -> put_in(Acc, entry(N, 7)) end,
                    roster:new(test, 8), lists:seq(1, 5)),
    ?assertEqual(roster:entry_id(roster:worst(R)), roster:entry_id(roster:worst(R))),
    ?assertNotEqual(roster:entry_id(roster:worst(R)), roster:entry_id(roster:best(R))).

%% ⚠ THE CAP IS THE MECHANISM, NOT A LIMIT. CHARTER.md spends a genome when it
%% flies, and an unbounded archive would make losing a raid free.
a_full_roster_evicts_the_worst_for_something_better_test() ->
    R = full(4),
    ?assertEqual(4, roster:depth(R)),
    {admitted, R2} = roster:admit(R, entry(99, 100)),
    ?assertEqual(4, roster:depth(R2)),
    ?assertEqual(100, roster:entry_fitness(roster:best(R2))),
    ?assertEqual(2, roster:entry_fitness(roster:worst(R2))).

a_full_roster_refuses_something_worse_test() ->
    R = full(4),
    ?assertMatch({refused, {not_better_than_worst, 1}}, roster:admit(R, entry(99, 0))),
    ?assertMatch({refused, {not_better_than_worst, 1}}, roster:admit(R, entry(99, 1))).

%% ⚠ A SORTIE REMOVES ENTRIES. The depth falls the moment drones launch, and only
%% survivors come back. Copying them out instead would make losing a raid free.
taking_for_a_sortie_removes_them_test() ->
    R = full(6),
    Ids = lists:sublist(roster:ids(R), 2),
    {Taken, Left} = roster:take(R, Ids),
    ?assertEqual(2, length(Taken)),
    ?assertEqual(4, roster:depth(Left)),
    [?assertNot(roster:has(Left, Id)) || Id <- Ids].

veteran_status_is_evidence_and_changes_no_gene_test() ->
    R = full(3),
    Id = hd(roster:ids(R)),
    Before = [E || E <- roster:entries(R), roster:entry_id(E) =:= Id],
    R2 = roster:tag_veteran(R, Id, {raid, elsewhere}),
    After = [E || E <- roster:entries(R2), roster:entry_id(E) =:= Id],
    ?assertEqual(0, roster:entry_veterancy(hd(Before))),
    ?assertEqual(1, roster:entry_veterancy(hd(After))),
    %% the genome is untouched: veterancy is a tag, not a change
    ?assertEqual(roster:entry_genome(hd(Before)), roster:entry_genome(hd(After))).

sampling_is_a_pure_function_of_the_generator_test() ->
    R = full(10),
    {A, _} = roster:sample(R, 3, seeded(1)),
    {B, _} = roster:sample(R, 3, seeded(1)),
    {C, _} = roster:sample(R, 3, seeded(2)),
    ?assertEqual(3, length(A)),
    ?assertEqual([roster:entry_id(E) || E <- A], [roster:entry_id(E) || E <- B]),
    ?assertNotEqual([roster:entry_id(E) || E <- A], [roster:entry_id(E) || E <- C]).

sampling_more_than_it_holds_gives_what_it_has_test() ->
    {S, _} = roster:sample(full(3), 10, seeded(1)),
    ?assertEqual(3, length(S)).

%%==============================================================================
%% Variation
%%==============================================================================

%% ⚠ EVERY DRAW IS THREADED. Register `D.5': one unrecorded draw was enough to
%% make the benchmark irreproducible and to break the property that a genome
%% specifies a controller.
breeding_is_a_pure_function_of_the_generator_test() ->
    {A, _} = breed:random(seeded(4)),
    {B, _} = breed:random(seeded(4)),
    {C, _} = breed:random(seeded(5)),
    ?assertEqual(A, B),
    ?assertNotEqual(A, C).

a_random_genome_is_valid_test() ->
    {G, _} = breed:random(seeded(11)),
    ?assertEqual(ok, drone_genome:validate(G)).

%% Sparse: a child is recognisably descended from its parent. Perturbing every
%% gene would make the search a random walk with extra steps.
mutation_moves_some_genes_and_not_most_test() ->
    {G, S} = breed:random(seeded(12)),
    {M, _} = breed:mutate(G, S, breed:sigma()),
    ?assertEqual(ok, drone_genome:validate(M)),
    Moved = length([x || {A, B} <- lists:zip(element(2, G), element(2, M)), A =/= B]),
    Total = length(element(2, G)),
    ?assert(Moved > 0),
    ?assert(Moved < Total div 4).

%% Clamped rather than wrapped: a wrapped weight turns the largest possible value
%% into the smallest, which is not a mutation but a different animal.
mutation_stays_in_range_test() ->
    #{weight_min := Lo, weight_max := Hi} = drone_genome:limits(),
    Count = drone_genome:gene_count(topology()),
    Extreme = {topology(), lists:duplicate(Count, Hi)},
    {M, _} = breed:mutate(Extreme, seeded(13), 30000),
    [?assert(G >= Lo andalso G =< Hi) || G <- element(2, M)].

crossover_takes_from_both_parents_test() ->
    Count = drone_genome:gene_count(topology()),
    A = {topology(), lists:duplicate(Count, 1000)},
    B = {topology(), lists:duplicate(Count, -1000)},
    {ok, Child, _} = breed:cross(A, B, seeded(14)),
    Genes = element(2, Child),
    ?assert(lists:member(1000, Genes)),
    ?assert(lists:member(-1000, Genes)),
    ?assertEqual(ok, drone_genome:validate(Child)).

%% ⚠ MISMATCHED TOPOLOGIES REFUSE RATHER THAN TRUNCATING. Two genomes of
%% different shape have no gene-to-gene correspondence, so a child of them would
%% be an arbitrary splice presented as a descendant.
crossing_different_shapes_refuses_test() ->
    ?assertEqual({error, topology_mismatch},
                 breed:cross(genome(1), {[41, 12, 10], []}, seeded(15))).

%%==============================================================================
%% One round
%%==============================================================================

%% Seeding is what a fresh island does, and it produces valid controllers.
seeding_fills_a_roster_test() ->
    {R, _} = trainer:seed_roster(roster:new(test, 6), 6, seeded(21)),
    ?assertEqual(6, roster:depth(R)),
    [?assertEqual(ok, drone_genome:validate(roster:entry_genome(E)))
     || E <- roster:entries(R)].

a_round_needs_two_parents_test() ->
    {R, Report, _} = trainer:round(roster:new(test, 6), #{rand => seeded(22)}),
    ?assertEqual(0, roster:depth(R)),
    ?assertEqual(too_few_parents, maps:get(outcome, Report)).

%% ⚠ THE OUTCOME IS REPORTED EITHER WAY. CHARTER.md rule 4: a trainer that has
%% proposed nothing and one whose every proposal was rejected look identical
%% without an exercise count.
a_round_reports_what_it_did_test() ->
    {R0, S} = trainer:seed_roster(roster:new(test, 4), 4, seeded(23)),
    {_R, Report, _S} = trainer:round(R0, #{rand => S}),
    ?assert(lists:member(maps:get(outcome, Report), [admitted, rejected])),
    ?assert(maps:is_key(challenger, Report)),
    ?assert(maps:is_key(incumbent, Report)).

%% A round is a pure function of the roster and the generator, which is what
%% makes a surprising champion reproducible.
a_round_is_deterministic_test() ->
    {R0, S} = trainer:seed_roster(roster:new(test, 4), 4, seeded(24)),
    {A, RepA, _} = trainer:round(R0, #{rand => S}),
    {B, RepB, _} = trainer:round(R0, #{rand => S}),
    ?assertEqual(roster:ids(A), roster:ids(B)),
    ?assertEqual(RepA, RepB).

%% The opponent set is the drills plus this island's own roster. At item 7 it
%% gains every foreign genome that has attacked here, which is CHARTER.md's one
%% idea in mechanical form.
the_opponent_set_is_drills_plus_the_roster_test() ->
    {R, _} = trainer:seed_roster(roster:new(test, 3), 3, seeded(25)),
    Opps = trainer:opponents(R),
    [?assert(lists:member(K, Opps)) || K <- drone_drills:kinds()],
    ?assertEqual(length(drone_drills:kinds()) + 3, length(Opps)).

points_are_stated_rather_than_implied_test() ->
    ?assertEqual(2, trainer:points(attacker)),
    ?assertEqual(1, trainer:points(draw)),
    ?assertEqual(0, trainer:points(defender)).

%%==============================================================================
%% The island
%%==============================================================================

a_fresh_island_seeds_itself_once_test() ->
    I = island:seed_if_empty(island:new(#{seed => 31, capacity => 8})),
    ?assert(island:roster_depth(I) > 0),
    Depth = island:roster_depth(I),
    ?assertEqual(Depth, island:roster_depth(island:seed_if_empty(I))).

%% ⚠ SEEDING IS IDEMPOTENT SO A RESTORED LINEAGE IS NEVER BURIED UNDER NOISE.
%% `island_server:init/1' restores first and seeds second, and this is the
%% property that makes that order safe.
seeding_leaves_a_restored_roster_alone_test() ->
    {R, _} = trainer:seed_roster(roster:new(restored, 8), 3, seeded(32)),
    I = island:with_roster(island:new(#{seed => 33, capacity => 8}), R),
    ?assertEqual(3, island:roster_depth(island:seed_if_empty(I))).

training_advances_the_counts_test() ->
    I0 = island:seed_if_empty(island:new(#{seed => 34, capacity => 6})),
    ?assertEqual(0, island:rounds_of(I0)),
    {I1, _Report} = island:train(I0),
    ?assertEqual(1, island:rounds_of(I1)),
    ?assert(island:admissions_of(I1) =< 1).

%% Until an exam has been sat, `starts' is zero, which a reader must be able to
%% tell from having sat it and lost everything.
an_island_has_not_sat_the_exam_until_it_has_test() ->
    I = island:new(#{seed => 35}),
    ?assertEqual(0, maps:get(starts, island:benchmark_of(I))),
    %% ⚠ BOTH EXAMS START UNSAT, and the held-out one starts carrying the HELD-OUT
    %% rung names. An empty profile that named the curriculum's rungs would put
    %% the wrong six words beside the right zeros, and a reader has nothing else
    %% to tell the two vectors apart by.
    ?assertEqual(0, maps:get(starts, island:trials_of(I))),
    ?assertEqual(drone_trials:kinds(), maps:get(rungs, island:trials_of(I))),
    ?assertEqual(unknown, island:sitter_of(I)),
    Sat = island:benchmarked(I, #{rungs => [], wins => [], draws => [],
                                  losses => [], starts => 4},
                             #{rungs => [], wins => [], draws => [],
                               losses => [], starts => 7},
                             {captured, <<"beam01">>, <<"r1">>}),
    ?assertEqual(4, maps:get(starts, island:benchmark_of(Sat))),
    ?assertEqual(7, maps:get(starts, island:trials_of(Sat))),
    %% ⚠ AND WHO SAT IT. `roster:best/1' can be a captured genome, so a score
    %% without a provenance cannot distinguish an evolutionary collapse from a
    %% change of champion.
    ?assertMatch({captured, _From, _Raid}, island:sitter_of(Sat)).

%%==============================================================================
%% What a raid does to the entries that fly it
%%==============================================================================

%% ⚠ THE SORTIE COUNTER WAS A SILENT NO-OP FOR THE WHOLE LIFE OF THE TRACK.
%% `raid:sortie/3' evicts the party with `roster:take/2' and the old code then
%% called `roster:count_sortie(RosterWithoutThem, Id)', which looked the id up in
%% a map it had just been removed from, got `undefined', and returned the roster
%% unchanged. Measured on beam03 on 2026-08-09 after 2,524 raids: max sorties
%% across all 71 entries was 0, and every champion ever published carried
%% `champion_sorties => 0'.
%%
%% ⚠⚠ AND THE OBVIOUS REPAIR WOULD HAVE BEEN WORSE THAN THE BUG. Counting on the
%% roster BEFORE the take, or writing the entry back after it, re-inserts a
%% controller that is supposed to be airborne — so the island would field the
%% same genome at home and away at once, and the roster's finiteness, which is
%% the entire price of a raid, would be decorative.
a_party_carries_its_sortie_count_home_test() ->
    R = populated(70),
    {Party, Left, _S} = raid:sortie(R, rand:seed_s(exsss, {7, 7, 7}), 3),
    ?assertEqual(3, length(Party)),

    %% Stamped on the way out, on the records that travel.
    [?assertEqual(1, roster:entry_sorties(E)) || E <- Party],

    %% And NOT on the roster that stayed behind, which no longer holds them.
    [?assertEqual(undefined, held(Left, roster:entry_id(E))) || E <- Party],

    %% They come home carrying it, because `settle/3' re-admits the very record
    %% it was handed.
    {Back, _Home, _Lost} =
        raid:settle(Left, Party, [{roster:entry_id(E), survived} || E <- Party]),
    [?assertEqual(1, roster:entry_sorties(held(Back, roster:entry_id(E)))) || E <- Party],

    %% A second raid by the same controllers counts again rather than resetting.
    {Party2, Left2, _S2} = raid:sortie(Back, rand:seed_s(exsss, {7, 7, 7}), 3),
    {Back2, _H2, _L2} =
        raid:settle(Left2, Party2, [{roster:entry_id(E), survived} || E <- Party2]),
    Flown = [roster:entry_sorties(E) || E <- roster:entries(Back2)],
    ?assert(lists:max(Flown) >= 2).

held(R, Id) ->
    case [E || E <- roster:entries(R), roster:entry_id(E) =:= Id] of
        [E] -> E;
        [] -> undefined
    end.

%%==============================================================================
%% How a captured genome earns a local number
%%==============================================================================

%% ⚠⚠⚠ A CAPTURED GENOME COULD NEVER BECOME CHAMPION, SO THE ARCHIPELAGO'S
%% CENTRAL CLAIM WAS UNOBSERVABLE BY CONSTRUCTION. `raid:absorb/3' admits a
%% foreign genome at fitness 0 deliberately, and says it "earns a local number
%% only if the local trainer ever sits it". The trainer sits it every time it is
%% the worst entry — and then discarded the number. So it stayed at 0, stayed the
%% worst, and `roster:best/1' orders on stored fitness, so it could never be the
%% sitter of the exam and never be published as the champion.
%%
%% Measured on beam03 on 2026-08-09: 52 bred entries at fitness 10 to 30, and all
%% 19 captured entries at exactly 0. The exhibit reported "0 of 10 crossed the
%% mesh" and that number was never evidence about the world. `REGISTER I.25'.
a_captured_genome_earns_a_local_fitness_by_being_sat_test() ->
    R0 = populated(6),
    {ok, Foreign} = with_seed(99),
    Captured = raid:absorb(R0, [{drone_genome:id(Foreign), Foreign}],
                           #{from => <<"beam01">>, raid => <<"r1">>, tick => 0}),

    Entry = held(Captured, drone_genome:id(Foreign)),
    ?assertNotEqual(undefined, Entry),
    ?assertEqual(0, roster:entry_fitness(Entry)),
    %% Fitness 0 makes it the worst, which is exactly who the trainer sits.
    ?assertEqual(drone_genome:id(Foreign), roster:entry_id(roster:worst(Captured))),

    {After, Report, _S} =
        trainer:round(Captured, #{rand => rand:seed_s(exsss, {3, 3, 3}), tick => 1}),

    %% ⚠ THE PRECONDITION IS ASSERTED, NOT ASSUMED. The incumbent's measured
    %% score is what should be written back, and if this seed ever produces a
    %% zero the equality below would hold for the BROKEN code too — a test that
    %% passes for the wrong reason. It fails here instead, loudly.
    Measured = maps:get(incumbent, Report),
    ?assert(Measured > 0),

    %% The captured genome now carries the number it just earned, in place of the
    %% zero it was admitted with. Unless the challenger displaced it, which is
    %% the one outcome where there is no entry left to carry anything.
    case held(After, drone_genome:id(Foreign)) of
        undefined -> ?assert(maps:get(outcome, Report) =:= admitted);
        Still -> ?assertEqual(Measured, roster:entry_fitness(Still))
    end.

populated(N) ->
    lists:foldl(fun (I, R) -> put_in(R, entry(I, I)) end,
                roster:new(island, N + 8), lists:seq(1, N)).

with_seed(Seed) ->
    {G, _S} = breed:random(rand:seed_s(exsss, {Seed, Seed, Seed})),
    {ok, G}.

%%==============================================================================
%% Whom the exhibit's bout is flown against
%%==============================================================================

%% ⚠ THE PUBLISHED BOUT WAS HARDCODED TO A SCRIPTED DRILL, AND SO SHOWED THE
%% MINORITY CASE 100% OF THE TIME. `trainer:opponents/1' is the six curriculum
%% drills PLUS every roster entry, and a round samples four from it, so with the
%% live rosters between 70 and 240 a drill turns up in roughly 9% to 28% of
%% rounds. The exhibit drew one in every bout.
%%
%% ⚠⚠ AND IT WAS THE LEAST INFORMATIVE FIGHT AVAILABLE. Since `REGISTER I.22' the
%% drills are exactly the set the island trains against, so the page showed a
%% saturated champion beating its own homework in about a hundred ticks, and
%% never showed a controller against another controller — which is the
%% coevolution the archipelago exists for.
the_exhibited_bout_draws_from_the_real_opponent_set_test() ->
    R = populated(40),
    Champion = roster:entry_id(roster:best(R)),

    Drawn = [island_server:bout_opponent(R, Champion, T) || T <- lists:seq(0, 199)],

    %% Roster controllers dominate, because the pool is 40 of them against six
    %% drills. A drill still appears, at about its real rate.
    Controllers = length([O || O <- Drawn, is_binary(O)]),
    Drills = length([O || O <- Drawn, is_atom(O)]),
    ?assert(Controllers > 0),
    ?assert(Drills > 0),
    ?assert(Controllers > Drills),

    %% ⚠ NEVER ITSELF. A champion against its own id is a mirror match, and the
    %% roster holds exactly one of each genome.
    ?assertEqual([], [O || O <- Drawn, O =:= Champion]),

    %% Every drill drawn is a real rung and every controller drawn is really held.
    [?assert(lists:member(O, drone_drills:kinds())) || O <- Drawn, is_atom(O)],
    [?assert(roster:has(R, O)) || O <- Drawn, is_binary(O)].

%% An island with nothing but its champion has nobody to fly against, and that is
%% a bout not flown rather than a crash on the island's own timer.
a_bout_with_no_opponent_is_refused_rather_than_crashing_test() ->
    R = populated(1),
    Only = roster:entry_id(roster:best(R)),
    Drills = length(drone_drills:kinds()),
    %% The drills are still there, so it is not undefined; strip them to reach
    %% the degenerate case the guard exists for.
    ?assert(is_atom(island_server:bout_opponent(R, Only, 0))),
    ?assertEqual(Drills, length(trainer:opponents(R)) - 1).

%% ⚠⚠ A CAPTURED OPPONENT MUST BE DISTINGUISHABLE ON THE WIRE. Two genome ids in
%% `entrants' look identical whether the second was bred here or taken off a
%% neighbour in a raid, and only the island can tell, because only it holds the
%% roster entry's origin. A bout against a captured controller is the
%% archipelago's central claim in its most watchable form.
a_bout_says_what_kind_of_opponent_it_flew_test() ->
    R0 = populated(6),
    {ok, Foreign} = with_seed(77),
    R = raid:absorb(R0, [{drone_genome:id(Foreign), Foreign}],
                    #{from => <<"beam01">>, raid => <<"r9">>, tick => 0}),

    Encoded = fun (Opponent) ->
                      Meta = maps:merge(#{kind => training, bout => 1, start_index => 0,
                                          entrants => [<<"mine">>, <<"theirs">>]},
                                        island_server:bout_provenance(Opponent, R)),
                      dronex_bout:encode(Meta, #{winner => draw, ticks => 1}, [],
                                         airspace:limits())
              end,

    Drill = Encoded(hoverer),
    ?assertEqual(<<"drill">>, maps:get(opponent, Drill)),
    ?assertEqual(undefined, maps:get(opponent_from, Drill)),

    Bred = Encoded(roster:entry_id(roster:best(R0))),
    ?assertEqual(<<"bred">>, maps:get(opponent, Bred)),

    Captured = Encoded(drone_genome:id(Foreign)),
    ?assertEqual(<<"captured">>, maps:get(opponent, Captured)),
    ?assertEqual(<<"beam01">>, maps:get(opponent_from, Captured)).

