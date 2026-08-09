%% @doc The invader archive and the master tournament.
-module(invaders_tests).

-include_lib("eunit/include/eunit.hrl").

genome(N) ->
    {In, H, Out} = drone_genome:topology(),
    Topology = [In] ++ H ++ [Out],
    Count = drone_genome:gene_count(Topology),
    {Topology, [N rem 4000 | lists:duplicate(Count - 1, 0)]}.

seeded(N) -> rand:seed_s(exsss, {N, N, N}).

%% An archive with one invader per given tick.
witnessed(Ticks) ->
    lists:foldl(fun ({N, At}, A) ->
                        invaders:witness(A, genome(N), <<"beam01">>, <<"r">>, At)
                end,
                invaders:new(),
                lists:zip(lists:seq(1, length(Ticks)), Ticks)).

%%==============================================================================
%% ⚠ THE GUARD. It is the reason this is a separate collection from the roster.
%%==============================================================================

%% ⚠⚠ AN ARCHIVE BUILT FROM THE GENOMES THE ISLAND TRAINS AGAINST IS A TEST SET
%% INSIDE ITS OWN TRAINING DISTRIBUTION, WHICH IS `REGISTER I.22' EXACTLY. That
%% fault made the frozen exam meaningless for the whole life of this track and
%% was found on 2026-08-08. Building the next instrument the same way the day
%% after would be paying for it twice.
%%
%% `raid:absorb/3' admits captured genomes into the roster on purpose, and
%% `trainer:opponents/1' is every roster entry. So a raid's haul is SPLIT: the
%% sequestered share is never admitted, and this is what says so.
a_sequestered_invader_is_never_an_opponent_test() ->
    Haul = [{drone_genome:id(genome(N)), genome(N)} || N <- lists:seq(1, 60)],
    Held = [{Id, G} || {Id, G} <- Haul, invaders:sequestered(Id, invaders:share())],
    Trained = [{Id, G} || {Id, G} <- Haul, not invaders:sequestered(Id, invaders:share())],

    %% The split actually splits: neither side is everything.
    ?assert(Held =/= []),
    ?assert(Trained =/= []),
    ?assertEqual(length(Haul), length(Held) + length(Trained)),

    %% Only the trained share reaches the roster, so only it can become an
    %% opponent.
    R = lists:foldl(fun ({Id, G}, Acc) ->
                            raid:absorb(Acc, [{Id, G}],
                                        #{from => <<"beam01">>, raid => <<"r1">>, tick => 0})
                    end, roster:new(island, 240), Trained),

    Opponents = trainer:opponents(R),
    [?assertNot(lists:member(Id, Opponents)) || {Id, _G} <- Held],
    [?assert(lists:member(Id, Opponents)) || {Id, _G} <- Trained].

%% ⚠ THE SPLIT IS A FUNCTION OF THE ID AND NOTHING ELSE, so the same controller
%% is held out on whichever island meets it, and anybody can check that a given
%% genome was held out here without being told what the split was.
the_split_is_reproducible_from_the_genome_alone_test() ->
    Ids = [drone_genome:id(genome(N)) || N <- lists:seq(1, 200)],
    Once = [invaders:sequestered(Id, 4) || Id <- Ids],
    Again = [invaders:sequestered(Id, 4) || Id <- Ids],
    ?assertEqual(Once, Again),
    %% Roughly a quarter, which is what one-in-four means. Wide bounds, because
    %% this asserts the split is a split and not that sha256 is uniform.
    Held = length([x || true <- Once]),
    ?assert(Held > 20),
    ?assert(Held < 80).

%%==============================================================================
%% Eras
%%==============================================================================

%% ⚠ THE BANDS ARE LOGARITHMIC IN AGE, which is what makes ancient invaders
%% survive without a policy that has to be maintained. Recent arrivals are
%% numerous and crowd the low bands; a single old one holds a high band alone.
eras_are_the_log_of_age_test() ->
    A = witnessed([1000, 999, 992, 900, 500, 1]),
    Now = 1000,
    Bands = invaders:bands(A, Now),
    %% Six invaders across several distinct eras rather than all in one.
    ?assert(maps:size(Bands) >= 4),
    %% The one that arrived at tick 1 is the oldest and sits in the highest band.
    Oldest = lists:max(maps:keys(Bands)),
    [E] = maps:get(Oldest, Bands),
    ?assertEqual(1, invaders:entry_seen_at(E)).

%% ⚠⚠ FULL MEANS DROP FROM THE FULLEST ERA, NEVER THE OLDEST ENTRY. Evicting the
%% oldest is the obvious policy and is exactly wrong: it empties the bands the
%% instrument exists to keep, and the archive silently becomes "the last hundred
%% invaders", which cannot tell progress from cycling.
a_full_archive_keeps_its_oldest_eras_test() ->
    Small = invaders:new(8),
    Ancient = invaders:witness(Small, genome(1), <<"beam01">>, <<"r">>, 1),

    %% Now bury it under a flood of recent arrivals.
    Flooded =
        lists:foldl(fun (N, A) ->
                            invaders:witness(A, genome(N), <<"beam01">>, <<"r">>, 10_000 + N)
                    end, Ancient, lists:seq(2, 40)),

    ?assertEqual(8, invaders:depth(Flooded)),
    ?assert(lists:member(drone_genome:id(genome(1)), invaders:ids(Flooded))).

%% Idempotent on the id: an island raided twice by the same controller holds it
%% once, and re-admitting would reset the era and make an old invader look new.
the_same_invader_twice_is_one_invader_test() ->
    A = invaders:witness(invaders:new(), genome(1), <<"beam01">>, <<"r1">>, 5),
    B = invaders:witness(A, genome(1), <<"beam01">>, <<"r2">>, 900),
    ?assertEqual(1, invaders:depth(B)),
    [E] = invaders:entries(B),
    ?assertEqual(5, invaders:entry_seen_at(E)).

%%==============================================================================
%% Sampling
%%==============================================================================

%% ⚠⚠⚠ ONE FROM EACH ERA BEFORE A SECOND FROM ANY. A flat draw over an archive
%% whose recent band holds fifty and whose oldest holds one would almost never
%% fly the old one, so the measurement would quietly answer "can we beat what is
%% attacking us lately" — which the roster already answers.
a_sample_spreads_across_eras_before_it_doubles_up_test() ->
    Recent = [10_000 - N || N <- lists:seq(1, 30)],
    A = witnessed([1, 40, 600 | Recent]),
    Now = 10_000,

    {Picked, _S} = invaders:sample(A, 4, Now, seeded(1)),
    ?assertEqual(4, length(Picked)),

    Eras = [invaders:era_of(E, Now) || E <- Picked],
    ?assertEqual(length(Eras), length(lists:usort(Eras))).

a_sample_of_an_empty_archive_is_empty_test() ->
    {Picked, _S} = invaders:sample(invaders:new(), 5, 100, seeded(1)),
    ?assertEqual([], Picked).

sampling_is_a_pure_function_of_the_generator_test() ->
    A = witnessed([1, 40, 600, 9000, 9500, 9900]),
    {X, _} = invaders:sample(A, 3, 10_000, seeded(7)),
    {Y, _} = invaders:sample(A, 3, 10_000, seeded(7)),
    ?assertEqual([invaders:entry_id(E) || E <- X], [invaders:entry_id(E) || E <- Y]).

%%==============================================================================
%% The tournament
%%==============================================================================

%% ⚠ A PROFILE BY ERA AND NEVER A TOTAL, for the same reason the benchmark
%% refuses one: a single number needs weights across eras, and weights are a
%% judgement about which era matters smuggled into a measurement.
the_result_is_a_profile_and_never_a_number_test() ->
    A = witnessed([1, 500, 9000]),
    R = master:sit(genome(99), A, 10_000, #{fly => 3, starts => 1}),
    ?assertEqual([archived, draws, eras, flown, losses, wins], lists:sort(maps:keys(R))),
    ?assertNot(maps:is_key(score, R)),
    ?assertNot(maps:is_key(total, R)).

%% ⚠⚠ AN ISLAND THAT HAS FACED NOBODY IS NOT AN ISLAND THAT LOST. `flown' of
%% nought beside an empty profile is what says so, and the exam collapsed exactly
%% this distinction on 2026-08-09 when a failed sitting published an empty
%% profile that read as "never sat".
an_archive_with_nobody_in_it_says_so_test() ->
    R = master:sit(genome(1), invaders:new(), 100, #{fly => 3, starts => 1}),
    ?assertEqual(0, maps:get(flown, R)),
    ?assertEqual(0, maps:get(archived, R)),
    ?assertEqual([], maps:get(eras, R)).

%% A genome the engine will not fly is refused rather than scored zero, because a
%% zero is a legitimate result for a controller that lost everything.
an_unflyable_controller_is_refused_rather_than_scored_test() ->
    A = witnessed([1, 500]),
    R = master:sit({[1, 2], []}, A, 1000, #{fly => 2, starts => 1}),
    ?assertEqual(0, maps:get(flown, R)).

%% The eras come back in order and every vector is the same length as the era
%% list, because names travel with vectors and a reader must never have to
%% mirror a field order in its own source.
the_vectors_line_up_with_the_eras_test() ->
    A = witnessed([1, 40, 600, 9000]),
    R = master:sit(genome(5), A, 10_000, #{fly => 4, starts => 1}),
    N = length(maps:get(eras, R)),
    ?assert(N > 1),
    ?assertEqual(lists:sort(maps:get(eras, R)), maps:get(eras, R)),
    [?assertEqual(N, length(maps:get(K, R))) || K <- [wins, draws, losses]],
    %% Every fight is counted exactly once, whichever way it went.
    Total = lists:sum(maps:get(wins, R)) + lists:sum(maps:get(draws, R)) +
                lists:sum(maps:get(losses, R)),
    ?assertEqual(maps:get(flown, R), Total).
