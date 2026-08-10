#!/usr/bin/env escript
%%! -sname dronex_roster_shape
%%
%% The population, not its champion.
%%
%% THIS EXISTS BECAUSE EVERY GENOME NUMBER WE HAD RESTED ON ONE ENTRY PER ISLAND.
%% `roster:best/1` is by construction the unrepresentative genome, so a tau band
%% measured on five champions cannot tell a population fact from five accidents,
%% and a champion sitting near the seeding box cannot tell a short lineage from a
%% lucky draw.
%%
%% Reads the blobs `scripts/fetch_the_rosters.sh` brings home. Each row is
%% {Origin, Generation, Sorties, Taus, WMin, WMax, MeanAbsW}, summarised on the
%% island so a roster does not have to cross the wire.
%%
%% ⚠ THE SEEDED BAND IS THE REFERENCE AND IT IS ASKED OF `breed`, NOT TYPED IN.
%% Every question below is "how far outside what seeding can draw has the
%% population got", so the bound has to come from the thing that does the
%% drawing.
%%
%% ⚠⚠ AND IT WAS TYPED IN, AND IT LIED WITHIN THE HOUR. This carried
%% `-define(SEED_DRAW, 8192)` and a comment saying hardcoding the bound would
%% make it lie the day seeding changed. Seeding changed the same day. Run against
%% the new lineage it reported 1581 of 2184 time constants "outside a band
%% seeding can draw", against a seeding that now draws the whole range and has no
%% band at all. The comment predicted the failure exactly and did not prevent it,
%% because a warning next to a literal is still a literal.
%%
%% Usage:
%%   ERL_LIBS=_build/default/lib scripts/what_is_in_the_whole_roster.escript rosters

main([Dir]) -> report(Dir);
main(_Args) -> report("rosters").

report(Dir) ->
    Islands = islands(Dir),
    TauLo = drone_genome:to_tau(-breed:tau_draw()),
    TauHi = drone_genome:to_tau(breed:tau_draw() - 1),
    io:format("~nThe whole population, from ~s~n~n", [Dir]),
    %% ⚠ ~.0f IS NOT A VALID FORMAT. Erlang wants a precision of at least one
    %% digit after the point for ~f, and rejects the whole call rather than the
    %% one directive, so a percentage is rounded to an integer and printed ~b.
    io:format("  seeding can draw tau only in [~.3f, ~.3f], which is ~b% of the~n"
              "  expressible [~.3f, ~.3f). Weights only in +/-~b gene units.~n~n",
              [TauLo, TauHi, round(100 * (TauHi - TauLo) / (1.0 - 0.05)),
               drone_genome:to_tau(-32768), drone_genome:to_tau(32767),
               breed:weight_draw()]),
    population(Islands),
    origins(Islands),
    lineage(Islands),
    taus(Islands, TauLo, TauHi),
    weights(Islands),
    ok.

islands(Dir) ->
    {ok, Files} = file:list_dir(Dir),
    [island(Dir, F) || F <- lists:sort(Files), lists:suffix(".b64", F)].

island(Dir, File) ->
    {ok, B64} = file:read_file(filename:join(Dir, File)),
    Rows = binary_to_term(base64:decode(string:trim(B64))),
    {filename:basename(File, ".b64"), Rows}.

%%------------------------------------------------------------------------------

population(Is) ->
    io:format("  HOW BIG IS THE POPULATION~n~n"),
    io:format("  ~-8s ~8s ~10s~n", ["island", "entries", "capacity"]),
    [io:format("  ~-8s ~8b ~10b~n", [N, length(R), 240]) || {N, R} <- Is],
    io:format("~n").

%%------------------------------------------------------------------------------

%% ⚠ THE ORIGIN MIX IS THE CHURN QUESTION. A roster that is mostly captured
%% genomes is one whose own breeding is being outvoted by imports, and captures
%% enter at generation 0, so a high capture share also explains why generation
%% cannot be read as a breeding clock.
origins(Is) ->
    io:format("  WHERE THE POPULATION CAME FROM~n~n"),
    [origin_row(N, R) || {N, R} <- Is],
    io:format("  A high captured share means the island’s own lineage is a~n"
              "  minority of what it is breeding from.~n~n").

origin_row(Name, Rows) ->
    Tally = lists:foldl(fun({O, _G, _S, _T, _Mn, _Mx, _A}, Acc) ->
                            maps:update_with(tag(O), fun(C) -> C + 1 end, 1, Acc)
                        end, #{}, Rows),
    Total = length(Rows),
    Parts = [io_lib:format("~s ~b (~b%)", [K, V, round(100 * V / Total)])
             || {K, V} <- lists:sort(maps:to_list(Tally))],
    io:format("  ~-8s ~s~n", [Name, lists:flatten(lists:join("   ", Parts))]).

tag({A, _B}) -> atom_to_list(A);
tag(A) when is_atom(A) -> atom_to_list(A);
tag(Other) -> lists:flatten(io_lib:format("~p", [Other])).

%%------------------------------------------------------------------------------

lineage(Is) ->
    io:format("  HOW DEEP THE LINEAGES ARE~n~n"),
    io:format("  ~-8s ~10s ~10s ~10s ~12s~n",
              ["island", "gen max", "gen med", "gen zero", "sorties med"]),
    [lineage_row(N, R) || {N, R} <- Is],
    io:format("~n  Generation is reset to 0 by every capture, so it is a lower~n"
              "  bound on lineage depth and not a clock. Sorties is how many~n"
              "  times an entry has actually flown.~n~n").

lineage_row(Name, Rows) ->
    Gens = lists:sort([G || {_O, G, _S, _T, _Mn, _Mx, _A} <- Rows]),
    Sorties = lists:sort([S || {_O, _G, S, _T, _Mn, _Mx, _A} <- Rows]),
    io:format("  ~-8s ~10b ~10b ~10b ~12b~n",
              [Name, lists:last(Gens), median(Gens),
               length([G || G <- Gens, G =:= 0]), median(Sorties)]).

median([]) -> 0;
median(Sorted) -> lists:nth(max(1, length(Sorted) div 2), Sorted).

%%------------------------------------------------------------------------------

%% The question the champions could not answer: is the tau band a population
%% fact, and has ANY entry anywhere escaped the quarter-range seeding allows?
taus(Is, Lo, Hi) ->
    io:format("  TIME CONSTANTS ACROSS THE WHOLE POPULATION~n~n"),
    io:format("  ~-8s ~8s ~8s ~9s ~8s ~10s ~10s~n",
              ["island", "min", "max", "outside", "of", "fast<0.2", "slow>0.8"]),
    [tau_row(N, R, Lo, Hi) || {N, R} <- Is],
    io:format("~n  `outside` counts time constants beyond what seeding can draw,~n"
              "  so it is everything mutation has managed to add. Fast and slow~n"
              "  are the ends of the range the encoding actually offers.~n~n").

tau_row(Name, Rows, Lo, Hi) ->
    Ts = [drone_genome:to_tau(Q) || {_O, _G, _S, T, _Mn, _Mx, _A} <- Rows, Q <- T],
    N = length(Ts),
    io:format("  ~-8s ~8.3f ~8.3f ~9b ~8b ~10b ~10b~n",
              [Name, lists:min(Ts), lists:max(Ts),
               length([X || X <- Ts, X < Lo orelse X > Hi]), N,
               length([X || X <- Ts, X < 0.2]),
               length([X || X <- Ts, X > 0.8])]).

%%------------------------------------------------------------------------------

weights(Is) ->
    io:format("  HOW FAR THE WEIGHTS HAVE LEFT THE SEEDING BOX OF PLUS OR MINUS ~.1f~n~n",
              [breed:weight_draw() / drone_genome:scale()]),
    io:format("  ~-8s ~10s ~12s ~9s ~6s~n",
              ["island", "furthest", "median |w|", "outside", "of"]),
    [weight_row(N, R) || {N, R} <- Is],
    io:format("~n  Furthest is the largest |w| anywhere in the population. Entries~n"
              "  outside is how many carry at least one gene seeding could not~n"
              "  have produced, which is the clearest sign mutation is working.~n~n").

weight_row(Name, Rows) ->
    Furthest = lists:max([max(abs(Mn), abs(Mx))
                          || {_O, _G, _S, _T, Mn, Mx, _A} <- Rows]),
    Means = lists:sort([A || {_O, _G, _S, _T, _Mn, _Mx, A} <- Rows]),
    Box = breed:weight_draw() / drone_genome:scale(),
    Outside = length([1 || {_O, _G, _S, _T, Mn, Mx, _A} <- Rows,
                           Mn < -Box orelse Mx > Box]),
    io:format("  ~-8s ~10.3f ~12.3f ~9b ~6b~n",
              [Name, Furthest, median(Means), Outside, length(Rows)]).
