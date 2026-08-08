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
%% ⚠⚠⚠ A HARD LADDER CANNOT BE GRADED WITH RANDOM CONTROLLERS, and that is the
%% one thing this script had to learn to do. Random weights score nothing against
%% opponents that shoot and close, and six zeroes look exactly like a beautifully
%% graded instrument whose bottom rung nobody has reached yet. So it also reads
%% real champions, fetched by `scripts/fetch_the_champions.sh', because only a
%% controller that learnt something can tell HARD from IMPOSSIBLE.
%%
%% Usage:
%%   ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript
%%   ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript 12
%%   ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript 12 drone_trials
%%   ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript 12 drone_trials champions

main(Args) ->
    Starts = starts(Args),
    Ladder = ladder(Args),
    io:format("~nThe ~p ladder, over ~p of ~p starts.~n~n",
              [Ladder, Starts, benchmark:starts()]),
    io:format("A profile is a CURVE and is never summed. Six rungs, each a~n"
              "win rate. Won at the bottom and lost at the top is what a~n"
              "graded instrument looks like.~n~n"),
    io:format("  rungs: ~p~n~n", [benchmark:rungs(Ladder)]),
    [report(Name, G, Starts, Ladder) || {Name, G} <- champions(Args) ++ controllers()],
    soundness(Starts, Ladder),
    ok.

ladder([_Starts, L | _]) -> list_to_atom(L);
ladder(_Args) -> benchmark:curriculum_ladder().

%% ⚠ A MISSING CHAMPION DIRECTORY IS AN EMPTY LIST AND NOT A CRASH, so the script
%% still runs offline against random controllers alone. It says how many it read,
%% because "graded against the fleet" and "graded against nothing" must never
%% look the same on a page of numbers.
champions([_Starts, _Ladder, Dir | _]) -> loaded(file:list_dir(Dir), Dir);
champions(_Args) -> [].

loaded({error, Why}, Dir) ->
    io:format("  no champions read from ~s (~p)~n~n", [Dir, Why]),
    [];
loaded({ok, Files}, Dir) ->
    Cs = [champion(Dir, F) || F <- lists:sort(Files), lists:suffix(".b64", F)],
    io:format("  ~p champions read from ~s~n~n", [length(Cs), Dir]),
    Cs.

champion(Dir, File) ->
    {ok, B64} = file:read_file(filename:join(Dir, File)),
    {ok, G} = drone_genome:unpack(base64:decode(string:trim(B64))),
    {"champion " ++ filename:basename(File, ".b64") ++ "   (LIVE, from the fleet)", G}.

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
soundness(Starts, Ladder) ->
    io:format("~nDoes any drill kill itself? Each rung against a hoverer, which~n"
              "never shoots. A death here is the drill flying into something.~n~n"),
    io:format("  ~-10s ~8s ~8s~n", ["rung", "died", "withdrew"]),
    [io:format("  ~-10s ~8b ~8b~n", [atom_to_list(K), D, W])
     || {K, D, W} <- [alone(Ladder, K, Starts) || K <- benchmark:rungs(Ladder)]],
    io:format("~n").

alone(Ladder, Kind, Starts) ->
    Outcomes = [solo(Ladder, Kind, I) || I <- lists:seq(0, Starts - 1)],
    {Kind,
     length([O || O <- Outcomes, O =:= died]),
     length([O || O <- Outcomes, O =:= withdrew])}.

solo(Ladder, Kind, Index) ->
    {ok, Subject} = engagement:controller({Ladder, Kind}),
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

report(Name, Genome, Starts, Ladder) ->
    T0 = erlang:monotonic_time(millisecond),
    {ok, P} = benchmark:sit(Genome, #{starts => Starts, ladder => Ladder}),
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
