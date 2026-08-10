%% @doc A contest decides who leaves, not whether anyone may enter.
%%
%% THESE EXIST BECAUSE FIVE ROSTERS SAT AT 60 TO 153 OF A CAPACITY OF 240 after
%% twelve thousand rounds. A child that lost to the worst entry was dropped even
%% when a hundred and eighty seats were empty, so the population could only ever
%% grow on a win. The roster is also the parent pool and the opponent set, so
%% keeping it small narrows both.
%%
%% ⚠ THE INCUMBENT IS RE-MEASURED, SO A TEST CANNOT RIG WHO WINS. `contested/5'
%% scores the incumbent freshly against the same opponents and starts as the
%% challenger, and ignores the stored fitness for that purpose. The first draft
%% of these tests seeded incumbents at a fitness of a million and expected every
%% child to lose; the child won, because the million was never consulted. So
%% these assert the INVARIANT rather than a particular winner: while there is
%% room, nothing is turned away, whoever won.
%%
%% ⚠⚠ AND THEY CARRY TIMEOUTS. A round flies 2 genomes against 4 opponents over 4
%% starts, and eunit allows a test five seconds. The first draft timed out inside
%% `network_evaluator', which reads like an engine fault and is a missing wrapper.
-module(trainer_seating_tests).

-include_lib("eunit/include/eunit.hrl").

seeded(N) -> rand:seed_s(exsss, {N, N + 1, N + 2}).

with_entries(Capacity, Held, S0) ->
    lists:foldl(fun(_I, {R, S}) ->
                    {G, S1} = breed:random(S),
                    E = roster:entry(G, #{origin => {bred, test}, fitness => 0}),
                    {admitted, R1} = roster:admit(R, E),
                    {R1, S1}
                end, {roster:new(test, Capacity), S0}, lists:seq(1, Held)).

round_once(R, S) -> trainer:round(R, #{rand => S, tick => 1, island => test}).

rounds(R0, S0, N) ->
    lists:foldl(fun(_I, {R, S, Outcomes}) ->
                    {R1, Rep, S1} = round_once(R, S),
                    {R1, S1, [maps:get(outcome, Rep) | Outcomes]}
                end, {R0, S0, []}, lists:seq(1, N)).

%% ⚠ THE ONE THAT WAS RED. Whoever wins the contest, a roster with empty seats
%% must not turn a child away. Under the old trainer a losing child was dropped
%% and this list contained `rejected`.
nothing_is_rejected_while_there_is_room_test_() ->
    {timeout, 300, fun() ->
        {R0, S0} = with_entries(240, 2, seeded(3)),
        {_R1, _S1, Outcomes} = rounds(R0, S0, 12),
        ?assertEqual([], [O || O <- Outcomes, O =:= rejected])
    end}.

%% The same fact counted rather than pattern-matched: every round with room adds
%% exactly one entry, so depth tracks the round number.
every_round_with_room_adds_an_entry_test_() ->
    {timeout, 300, fun() ->
        {R0, S0} = with_entries(240, 2, seeded(4)),
        {R1, _S1, _Outcomes} = rounds(R0, S0, 12),
        ?assertEqual(14, roster:depth(R1))
    end}.

%% ⚠ AND THE GUARD ON THE OTHER SIDE. A full roster must never grow, or the
%% change would have turned a selective population into a queue. It may still
%% churn: a winner displaces the worst, which is the mechanism, not a leak.
a_full_roster_never_grows_test_() ->
    {timeout, 300, fun() ->
        {R0, S0} = with_entries(4, 4, seeded(5)),
        ?assertEqual(4, roster:depth(R0)),
        {R1, _S1, Outcomes} = rounds(R0, S0, 8),
        ?assertEqual(4, roster:depth(R1)),
        ?assertEqual([], [O || O <- Outcomes, O =:= seated])
    end}.

%% A seated entry carries the fitness it actually earned, so it is comparable
%% with the incumbents from the moment it arrives and is displaced first if it
%% deserves to be. Admitting at zero would make every seated entry the worst.
a_seated_entry_keeps_the_score_it_earned_test_() ->
    {timeout, 300, fun() ->
        {R0, S0} = with_entries(240, 2, seeded(11)),
        {R1, Report, _S1} = round_once(R0, S0),
        Mine = maps:get(challenger, Report),
        Fitnesses = [roster:entry_fitness(E) || E <- roster:entries(R1)],
        ?assert(lists:member(Mine, Fitnesses))
    end}.

%% Seating and winning are named apart, so a log or a fact can never confuse a
%% child that earned its place with one that filled a gap.
seating_is_reported_apart_from_winning_test_() ->
    {timeout, 300, fun() ->
        {R0, S0} = with_entries(240, 2, seeded(13)),
        {_R1, _S1, Outcomes} = rounds(R0, S0, 12),
        ?assertEqual([], [O || O <- Outcomes, O =/= seated andalso O =/= admitted])
    end}.
