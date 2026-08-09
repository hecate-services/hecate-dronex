#!/usr/bin/env escript
%%! -sname dronex_distant
%%
%% Does a fight that begins out of sight still finish?
%%
%% ⚠ WHY THIS EXISTS. `REGISTER D.4': the first drill ladder was written in an
%% order that turned out to be backwards, and only pointing known controllers at
%% it revealed that. A start set is the same kind of object and carries the same
%% obligation, and the risk here is the exact opposite of the one it fixes.
%%
%% `drone_starts' puts two sides 400 m apart, inside both the 600 m sensor and
%% the 600 m interceptor, so every recorded fight opens with a weapon already in
%% the air. `distant_starts' puts them 800 m apart, outside both. The thing that
%% could go wrong is that controllers never find each other at all, every
%% engagement runs to the battery, and the set produces draws instead of results
%% — measuring nothing, in a new and more expensive way.
%%
%% So this prints, for both sets, the three numbers that separate those cases:
%%
%%   decided     a fight with a winner. A set of draws is a broken set.
%%   first shot  which tick a munition first exists. Zero is the free strategy.
%%   ticks       how long a fight runs. The frozen set finishes before the sides
%%               could have met.
%%
%% ⚠⚠ IT IS A DIAGNOSTIC, NOT A GATE. `CHARTER.md' rule 3: nothing here is tuned
%% on what it prints, and the whole sweep is published rather than the reading
%% somebody liked.
%%
%% Usage:
%%   ERL_LIBS=_build/default/lib scripts/what_does_a_distant_start_look_like.escript
%%   ERL_LIBS=_build/default/lib scripts/what_does_a_distant_start_look_like.escript 24

main(Args) ->
    Starts = starts(Args),
    io:format("~nA fight that begins out of sight: does it still finish?~n~n"),
    io:format("Both sets, the same controllers, ~p starts each.~n", [Starts]),
    io:format("The sensor and the guided interceptor both reach 600 m.~n~n"),

    io:format("  ~-16s ~-22s ~8s ~9s ~10s ~11s~n",
              ["set", "controllers", "decided", "1st shot", "med ticks", "unseen t0"]),

    [report(Set, Name, Pair, Starts)
     || Set <- [drone_starts, distant_starts],
        {Name, Pair} <- controllers()],
    io:format("~n"),
    ok.

report(Set, Name, {A, B}, Starts) ->
    Runs = [one(Set, A, B, I) || I <- lists:seq(0, Starts - 1)],
    Decided = length([x || #{winner := W} <- Runs, W =/= draw]),
    Shots = [S || #{first_shot := S} <- Runs, S =/= none],
    Ticks = lists:sort([T || #{ticks := T} <- Runs]),
    Unseen = length([x || #{seen_at_start := false} <- Runs]),

    io:format("  ~-16s ~-22s ~6b/~-2b ~9s ~10b ~9b/~b~n",
              [atom_to_list(Set), Name, Decided, Starts,
               first_shot_of(Shots), median(Ticks), Unseen, Starts]).

first_shot_of([]) -> "never";
first_shot_of(Shots) ->
    lists:flatten(io_lib:format("~b", [lists:min(Shots)])).

median([]) -> 0;
median(Sorted) -> lists:nth(length(Sorted) div 2 + 1, Sorted).

%% ⚠ FRAMES ON, WHICH IS THE ONLY WAY TO SEE WHEN A WEAPON FIRST EXISTS. Every
%% other caller leaves them off because an engagement with the accumulator
%% running allocates an arena per tick.
one(Set, A, B, Index) ->
    {ok, Mine} = engagement:controller(A),
    {ok, Theirs} = engagement:controller(B),
    Placed = Set:place(1, 1, Index),
    [{AId, _, X1, Y1, Z1, _}, {DId, _, X2, Y2, Z2, _}] = Placed,
    Result = engagement:run(airspace:new(Placed), #{AId => Mine, DId => Theirs},
                            #{frames => true, network => ground_network:none()}),
    Frames = maps:get(frames, Result, []),

    #{winner => maps:get(winner, Result),
      ticks => maps:get(ticks, Result, 0),
      first_shot => first_munition(Frames, 0),
      seen_at_start =>
          fixed:mag3(X2 - X1, Y2 - Y1, Z2 - Z1) =< drone_senses:range()}.

%% The tick a munition first exists on, or `none' if nothing was ever fired.
first_munition([], _N) -> none;
first_munition([Frame | Rest], N) ->
    fired(airspace:munitions(world_of(Frame)), Rest, N).

%% ⚠ A FRAME IS THE WORLD AND THE DEFENDER'S BELIEF ABOUT IT, which is two
%% different things and the result record says so. An `#arena{}' has many fields
%% so it cannot match the pair clause by accident.
world_of({Arena, _Tracks}) -> Arena;
world_of(Arena) -> Arena.

fired([], Rest, N) -> first_munition(Rest, N + 1);
fired(_Any, _Rest, N) -> N.

starts([]) -> 16;
starts([N | _]) -> list_to_integer(N).

%% ⚠ A NULL AND TWO SEEDS, BECAUSE THE QUESTION IS ABOUT THE GEOMETRY AND NOT
%% ABOUT ANY PARTICULAR CONTROLLER. If a set only finishes for good controllers
%% it is not a set, it is a filter.
controllers() ->
    [{"null vs null", {null(), null()}},
     {"seed 1 vs seed 2", {random(1), random(2)}},
     {"seed 3 vs seed 4", {random(3), random(4)}}].

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

null() -> {topology(), lists:duplicate(drone_genome:gene_count(topology()), 0)}.

random(Seed) ->
    S0 = rand:seed_s(exsss, {Seed, Seed, Seed}),
    {Ws, _} = lists:foldl(fun (_N, {Acc, S}) ->
                                  {R, S1} = rand:uniform_s(S),
                                  {[(R - 0.5) * 4.0 | Acc], S1}
                          end, {[], S0},
                          lists:seq(1, drone_genome:gene_count(topology()))),
    {topology(), drone_genome:quantize(Ws)}.
