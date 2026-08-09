%% @doc The master tournament: what we have now, against everything that ever
%% attacked us, era by era. PURE and DETERMINISTIC.
%%
%% THIS EXISTS BECAUSE THE POINT IS TO SOLVE A PROBLEM, NOT TO RANK ISLANDS.
%%
%% ==========================================================================
%% ⚠ THE QUESTION IT ANSWERS, AND WHY NO SCRIPTED LADDER CAN ANSWER IT
%% ==========================================================================
%%
%% `benchmark' flies a controller against SCRIPTED opponents. That answers a
%% floor question — can this population beat a fixed standard — and a floor
%% question expires the moment it is cleared. `REGISTER D.16': the fleet solved
%% the frozen ladder in about a day. `I.23': the replacement was written the same
%% day and four of five islands were already at 91% within twelve hours.
%%
%% That is not bad luck and a third ladder would not fix it. Scripted behaviour
%% is finite, evolution finds its ceiling, and the ceiling arrives sooner each
%% time the population improves.
%%
%% The problem this archipelago is actually working on is a population of
%% controllers that can defeat invaders. Invaders are evolved, they keep coming,
%% and they get better — so the only standard that does not expire is the
%% invaders themselves.
%%
%% ==========================================================================
%% ⚠⚠ IT EXISTS TO DETECT CYCLING, WHICH IS THE FAILURE LOCAL NUMBERS HIDE
%% ==========================================================================
%%
%% A coevolving population can beat what it is fighting this week, lose to what
%% it beat last month, and go round in a circle with every local number rising
%% the whole time. Fitness rises, the roster churns, raids are won, and nothing
%% has been learned. That is the specific thing a master tournament is for, and
%% it is invisible to any measure that only looks at recent opponents.
%%
%% So the result is a profile BY ERA and never a total. A flat line across eras
%% is genuine dominance. A line that is high on recent eras and low on old ones
%% is cycling, and it is the single most important shape this repository can
%% draw, because it is the difference between progress and a treadmill.
%%
%% ==========================================================================
%% ⚠⚠⚠ NEVER SUMMED, FOR THE SAME REASON THE BENCHMARK IS NOT
%% ==========================================================================
%%
%% One number would need weights across eras, weights are a judgement about which
%% era matters, and a judgement smuggled into an instrument is the thing
%% instruments exist to avoid. `master_tests' asserts there is no `score' and no
%% `total' key, exactly as `benchmark_tests' does.
-module(master).

-include("airspace.hrl").

-export([sit/3, sit/4, empty/0]).

-export_type([result/0]).

-type result() :: #{eras := [non_neg_integer()],
                    wins := [non_neg_integer()],
                    draws := [non_neg_integer()],
                    losses := [non_neg_integer()],
                    %% How many invaders were flown in total, so a reader can
                    %% tell a thin measurement from a thorough one. CHARTER.md
                    %% rule 4: the exercise count sits beside every null.
                    flown := non_neg_integer(),
                    %% How many the archive holds, so a reader can tell "we have
                    %% faced little" from "we sampled little".
                    archived := non_neg_integer()}.

%% How many invaders one sitting flies, and over how many starts each. Small,
%% because this runs on the same four slow cores as everything else and the
%% archive spans eras rather than being large.
-define(FLY, 12).
-define(STARTS, 2).

%% @doc Nothing measured, for an island that has not sat it or has no archive.
%%
%% ⚠ ZEROS AND AN EXPLICIT `flown' OF NOUGHT, never an absent key. A reader must
%% be able to tell "faced nobody yet" from "faced them and lost", which is the
%% distinction `benchmark:empty/0' exists for and the one the exam collapsed on
%% 2026-08-09 when a failed sitting published an empty profile.
-spec empty() -> result().
empty() ->
    #{eras => [], wins => [], draws => [], losses => [], flown => 0, archived => 0}.

-spec sit(drone_genome:genome(), invaders:archive(), non_neg_integer()) -> result().
sit(Genome, Archive, Now) -> sit(Genome, Archive, Now, #{}).

%% @doc Fly this controller against a sample of the archive, spread across eras.
%%
%% ⚠ THE SAMPLE IS DRAWN ACROSS ERAS AND NOT ACROSS THE ARCHIVE. `invaders:sample/4'
%% takes one from each era before a second from any, because a flat draw over an
%% archive whose recent band holds fifty and whose oldest holds one would almost
%% never fly the old one — and the whole measurement is about the old one.
-spec sit(drone_genome:genome(), invaders:archive(), non_neg_integer(), map()) -> result().
sit(Genome, Archive, Now, Opts) ->
    flown(drone_genome:validate(Genome), Genome, Archive, Now, Opts).

%% ⚠ A REFUSED GENOME IS `empty()' AND THE CALLER MUST NOT PUBLISH IT AS A
%% READING. `island_server' learned this the hard way with the exam: a failed
%% sitting published `benchmark:empty()', which is the same shape as "never sat",
%% so a transient failure erased a good reading and claimed the island had never
%% been measured.
flown({error, _Why}, _G, _A, _Now, _Opts) -> empty();
flown(ok, Genome, Archive, Now, Opts) ->
    Rand = maps:get(rand, Opts, rand:seed_s(exsss, {Now, Now + 1, Now + 2})),
    {Picked, _S} = invaders:sample(Archive, maps:get(fly, Opts, ?FLY), Now, Rand),
    tallied(Picked, Genome, Archive, Now, maps:get(starts, Opts, ?STARTS)).

tallied([], _Genome, Archive, _Now, _Starts) ->
    (empty())#{archived => invaders:depth(Archive)};
tallied(Picked, Genome, Archive, Now, Starts) ->
    Grouped = by_era(Picked, Now),
    Eras = lists:sort(maps:keys(Grouped)),
    Tallies = [era_tally(maps:get(E, Grouped), Genome, Starts) || E <- Eras],

    #{eras => Eras,
      wins => [W || {W, _D, _L} <- Tallies],
      draws => [D || {_W, D, _L} <- Tallies],
      losses => [L || {_W, _D, L} <- Tallies],
      flown => length(Picked) * Starts,
      archived => invaders:depth(Archive)}.

by_era(Picked, Now) ->
    lists:foldl(fun (E, Acc) ->
                        B = invaders:era_of(E, Now),
                        maps:update_with(B, fun (Es) -> [E | Es] end, [E], Acc)
                end, #{}, Picked).

era_tally(Invaders, Genome, Starts) ->
    lists:foldl(fun (I, Acc) -> against(I, Genome, Starts, Acc) end, {0, 0, 0}, Invaders).

against(Invader, Genome, Starts, Acc) ->
    lists:foldl(fun (Ix, A) -> tally(one(Genome, invaders:entry_genome(Invader), Ix), A) end,
                Acc, lists:seq(0, Starts - 1)).

tally(attacker, {W, D, L}) -> {W + 1, D, L};
tally(draw, {W, D, L}) -> {W, D + 1, L};
tally(defender, {W, D, L}) -> {W, D, L + 1}.

%% ⚠ AN AWAY GAME, LIKE EVERY OTHER MEASUREMENT HERE. No ground network, so this
%% scores the controller and never the island's terrain. `CHARTER.md`: if a
%% measurement ran at home, an island that improved its FORTIFICATIONS would show
%% a rising score that was not about its drones at all.
%%
%% ⚠⚠ AND OUR CONTROLLER TAKES THE ATTACKER'S SEAT, WHICH IS THE HARDER ONE AND
%% IS ALSO THE HONEST ONE. The archive holds controllers that ATTACKED this
%% island, and the question is whether what we have now can beat them. Putting
%% ours in the defender's seat would measure them attacking us again, which is a
%% different question and one the raid record already answers.
one(Mine, Theirs, Index) ->
    {ok, A} = engagement:controller(Mine),
    {ok, D} = engagement:controller(Theirs),
    Placed = drone_starts:place(1, 1, Index),
    [{AId, _, _, _, _, _}, {DId, _, _, _, _, _}] = Placed,
    Result = engagement:run(airspace:new(Placed), #{AId => A, DId => D},
                            #{network => ground_network:none()}),
    maps:get(winner, Result).
