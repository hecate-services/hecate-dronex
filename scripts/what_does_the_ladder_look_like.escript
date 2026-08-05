#!/usr/bin/env escript
%%! -sname dronex_ladder
%%
%% Sit the frozen benchmark with controllers of known quality and print the
%% profile, so the LADDER can be read rather than assumed.
%%
%% ⚠ WHY THIS EXISTS. Insight 054: a benchmark that is not graded saturates and
%% goes silently blind, and a weak reference set there missed roughly 31 of about
%% 35 units of progress. A ladder every controller loses, or every controller
%% wins, reports nothing while looking exactly like a working instrument. The
%% only way to know which one this is, is to point known controllers at it and
%% look at the shape.
%%
%% ⚠⚠ IT IS A DIAGNOSTIC, NOT A GATE. Nothing here is tuned on what it prints.
%% CHARTER.md rule 3: a constant is chosen on viability and the whole sweep is
%% published, never set to whichever value produced a number somebody liked.
%%
%% Usage:
%%   ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript
%%   ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript 12

main(Args) ->
    Starts = starts(Args),
    io:format("~nThe frozen ladder, over ~p of ~p starts.~n~n",
              [Starts, benchmark:starts()]),
    io:format("A profile is a CURVE and is never summed. Six rungs, each a~n"
              "win rate. Won at the bottom and lost at the top is what a~n"
              "graded instrument looks like.~n~n"),
    [report(Name, G, Starts) || {Name, G} <- controllers()],
    soundness(Starts),
    ok.

%% ==========================================================================
%% ⚠ IS THE INSTRUMENT MEASURING THE CONTROLLER, OR THE DRILL?
%% ==========================================================================
%%
%% A rung whose drill kills itself is not a rung. It reports a win for whoever
%% was in the other seat, whatever they did, and it would look exactly like an
%% easy rung on the profile above.
%%
%% So: fly every drill against a HOVERER, which never shoots and never moves, and
%% count how often the drill dies anyway. Anything other than zero means that
%% rung is partly measuring the drill's own survival.
soundness(Starts) ->
    io:format("~nDoes any drill kill itself? Each rung against a hoverer, which~n"
              "never shoots. A death here is the drill flying into something.~n~n"),
    io:format("  ~-10s ~8s ~8s~n", ["rung", "died", "withdrew"]),
    [io:format("  ~-10s ~8b ~8b~n", [atom_to_list(K), D, W])
     || {K, D, W} <- [alone(K, Starts) || K <- benchmark:rungs()]],
    io:format("~n").

alone(Kind, Starts) ->
    Outcomes = [solo(Kind, I) || I <- lists:seq(0, Starts - 1)],
    {Kind,
     length([O || O <- Outcomes, O =:= died]),
     length([O || O <- Outcomes, O =:= withdrew])}.

solo(Kind, Index) ->
    {ok, Subject} = engagement:controller(Kind),
    {ok, Passive} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, Index),
    [{AId, _, _, _, _, _}, {DId, _, _, _, _, _}] = Placed,
    R = engagement:run(airspace:new(Placed),
                       #{AId => Subject, DId => Passive}),
    fate(AId, R).

fate(Id, #{survivors := S, withdrawn := W}) ->
    fated(lists:member(Id, S), lists:member(Id, W)).

fated(false, _W) -> died;
fated(true, true) -> withdrew;
fated(true, false) -> lived.

starts([]) -> 8;
starts([N | _]) -> list_to_integer(N).

%% ⚠ ONE NULL AND EIGHT SEEDS, BECAUSE TWO PROBES TOLD ME THE RANGE AND NOTHING
%% ABOUT THE RESOLUTION. The first reading used two random controllers and they
%% landed at opposite ends, 48/48 and 0/48, which is consistent with a beautifully
%% graded instrument AND with a game that is trivially won or trivially lost with
%% nothing in between. Only a spread distinguishes those.
controllers() ->
    [{"null      (all weights zero, commands nothing)", null()}
     | [{lists:flatten(io_lib:format("seed ~2b   (random weights)", [S])), random(S)}
        || S <- lists:seq(1, 8)]].

report(Name, Genome, Starts) ->
    T0 = erlang:monotonic_time(millisecond),
    {ok, P} = benchmark:sit(Genome, #{starts => Starts}),
    T1 = erlang:monotonic_time(millisecond),
    #{rungs := Rungs, wins := W, draws := D, losses := L, starts := N} = P,
    io:format("~s~n", [Name]),
    io:format("  ~-10s ~6s ~6s ~6s   ~s~n", ["rung", "won", "drew", "lost", ""]),
    %% `lists:zip4/4' does not exist, so the rows are indexed. Four parallel
    %% lists is the shape the fact carries, because names travel with vectors.
    [io:format("  ~-10s ~6b ~6b ~6b   ~s~n",
               [atom_to_list(lists:nth(K, Rungs)), lists:nth(K, W),
                lists:nth(K, D), lists:nth(K, L), bar(lists:nth(K, W), N)])
     || K <- lists:seq(1, length(Rungs))],
    io:format("  ~p engagements in ~p ms~n~n", [length(Rungs) * N, T1 - T0]).

bar(_W, 0) -> "";
bar(W, N) -> lists:duplicate(W * 20 div N, $#).

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

null() -> {topology(), lists:duplicate(drone_genome:gene_count(topology()), 0)}.

%% Seeded rather than drawn, so two runs of this script agree and a surprise is
%% a fact about the ladder rather than about the day.
random(Seed) ->
    S0 = rand:seed_s(exsss, {Seed, Seed, Seed}),
    {Ws, _} = lists:foldl(fun (_N, {Acc, S}) ->
                                  {R, S1} = rand:uniform_s(S),
                                  {[(R - 0.5) * 4.0 | Acc], S1}
                          end, {[], S0},
                          lists:seq(1, drone_genome:gene_count(topology()))),
    {topology(), drone_genome:quantize(Ws)}.
