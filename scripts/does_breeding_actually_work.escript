#!/usr/bin/env escript
%%! -sname dronex_breeding
%%
%% Seed a roster, run rounds, and sit the FROZEN benchmark every so often.
%%
%% ⚠ WHY THIS EXISTS. A trainer that runs without crashing is not a trainer that
%% works. Selection with no variation is a hall of fame with immigration, and
%% variation with a fitness measured against a moving exam is a number that rises
%% for reasons nobody can name. The only honest question is whether the frozen
%% ladder moves, because it is the one exam nothing trains against.
%%
%% ⚠⚠ IT IS A DIAGNOSTIC, NOT A GATE, and nothing is tuned on what it prints.
%% CHARTER.md rule 3: constants are chosen on viability and the whole sweep is
%% published, never set to whichever value produced a number somebody liked.
%%
%% Usage:
%%   ERL_LIBS=$PWD/_build/default/lib scripts/does_breeding_actually_work.escript
%%   ERL_LIBS=$PWD/_build/default/lib scripts/does_breeding_actually_work.escript 200 40 8

main(Args) ->
    {Rounds, Pop, Starts} = opts(Args),
    io:format("~nSeeding ~p controllers, then ~p breeding rounds.~n", [Pop, Rounds]),
    io:format("The frozen ladder is sat every ~p rounds, over ~p starts.~n~n",
              [max(1, Rounds div 4), Starts]),
    S0 = rand:seed_s(exsss, {20260805, 1, 1}),
    {R0, S1} = trainer:seed_roster(roster:new(probe, Pop), Pop, S0),
    io:format("  ~-8s ~-8s ~-9s ~s~n", ["round", "depth", "gen", "frozen ladder (wins)"]),
    show(0, R0, Starts),
    {Rn, _S} = loop(R0, S1, 1, Rounds, Starts),
    io:format("~n"),
    summarise(Rn),
    ok.

opts([]) -> {120, 24, 6};
opts([R]) -> {list_to_integer(R), 24, 6};
opts([R, P]) -> {list_to_integer(R), list_to_integer(P), 6};
opts([R, P, S | _]) -> {list_to_integer(R), list_to_integer(P), list_to_integer(S)}.

loop(R, S, N, Rounds, _Starts) when N > Rounds -> {R, S};
loop(R, S, N, Rounds, Starts) ->
    {R1, _Report, S1} = trainer:round(R, #{rand => S, tick => N, island => probe}),
    maybe_show(N, Rounds, R1, Starts),
    loop(R1, S1, N + 1, Rounds, Starts).

maybe_show(N, Rounds, R, Starts) -> shown(N rem max(1, Rounds div 4), N, R, Starts).

shown(0, N, R, Starts) -> show(N, R, Starts);
shown(_Other, _N, _R, _Starts) -> ok.

%% ⚠ THE BEST ENTRY BY LOCAL FITNESS IS WHAT SITS THE FROZEN LADDER, and its local
%% fitness is deliberately NOT printed beside it. Local fitness is measured
%% against the opponent set, which the roster itself is part of, so it rises as
%% the population improves whether or not the drones got better. Putting the two
%% numbers side by side invites reading one as corroborating the other.
show(N, R, Starts) ->
    Best = roster:best(R),
    io:format("  ~-8b ~-8b ~-9b ~s~n",
              [N, roster:depth(R), roster:generation_of(R), ladder(Best, Starts)]).

ladder(undefined, _Starts) -> "no entries";
ladder(Entry, Starts) ->
    {ok, P} = benchmark:sit(roster:entry_genome(Entry), #{starts => Starts}),
    #{wins := W} = P,
    lists:flatten([io_lib:format("~3b", [X]) || X <- W]).

summarise(R) ->
    io:format("  rungs: ~p~n", [benchmark:rungs()]),
    io:format("  roster depth ~p of ~p, deepest generation ~p~n",
              [roster:depth(R), roster:capacity(R), roster:generation_of(R)]),
    Origins = [roster:entry_origin(E) || E <- roster:entries(R)],
    io:format("  origins: ~p distinct~n", [length(lists:usort(Origins))]),
    Gens = lists:sort([roster:entry_generation(E) || E <- roster:entries(R)]),
    io:format("  generations held: ~p to ~p~n", [hd(Gens), lists:last(Gens)]).
