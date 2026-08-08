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
