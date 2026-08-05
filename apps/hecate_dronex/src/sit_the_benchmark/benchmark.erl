%% @doc The frozen exam. PURE and DETERMINISTIC.
%%
%% THIS EXISTS SO "THIS ISLAND GOT BETTER" IS A SENTENCE THAT CAN BE CHECKED.
%%
%% ==========================================================================
%% ⚠ WHY IT IS BUILT BEFORE ANYTHING IS BRED
%% ==========================================================================
%%
%% CHARTER.md order of work puts this at item 4, ahead of the trainer at item 5,
%% and the reason is that it cannot be added to history afterwards. An island
%% trains against an opponent set that raids keep widening: scripted drills, its
%% own past champions, and every foreign genome that has ever attacked it. A
%% fitness measured against THAT rises as the set changes, and a rising number
%% measured against a moving exam is an artifact, not progress.
%%
%% Insight 054 is the specific failure: a benchmark that is not fixed and graded
%% saturates and goes silently blind, and a weak reference set there missed
%% roughly 31 of about 35 units of progress.
%%
%% ==========================================================================
%% ⚠⚠ IT IS AN AWAY GAME, ALWAYS
%% ==========================================================================
%%
%% No ground sensors, no cueing, the comms ground bank forced to zero. If the
%% benchmark ran at home, an island that improved its FORTIFICATIONS would show a
%% rising benchmark score, and that score would not be about its drones at all.
%% That is insight 054 a second time, in a costume that would be much harder to
%% notice. The defence network is measured separately and the two are never added
%% together.
%%
%% ==========================================================================
%% ⚠⚠⚠ THE RESULT IS A PROFILE AND IS NEVER SUMMED
%% ==========================================================================
%%
%% Six rungs, each a win rate out of 48 starts. There is no `score', no `total'
%% and no weighted average, and `benchmark_tests' asserts that none of those keys
%% exists. A single number would need weights, weights are a judgement about
%% which rung matters, and a judgement smuggled into an instrument is the thing
%% instruments exist to avoid. A benchmark reads as a CURVE: won at the bottom
%% and lost at the top tells you where a population is, and one number tells you
%% almost nothing.
-module(benchmark).

-include("airspace.hrl").

-export([sit/1, sit/2, rungs/0, starts/0, empty/0]).

-export_type([profile/0]).

-type profile() :: #{rungs := [drone_drills:kind()],
                     wins := [non_neg_integer()],
                     draws := [non_neg_integer()],
                     losses := [non_neg_integer()],
                     %% ⚠ NON-NEG RATHER THAN POSITIVE, AND DIALYZER CAUGHT THE
                     %% DIFFERENCE. Zero starts is `empty/0': an island that has
                     %% not sat the exam. That is the whole reason the shape
                     %% exists, so the type has to be able to say it.
                     starts := non_neg_integer()}.

-spec rungs() -> [drone_drills:kind()].
rungs() -> drone_drills:kinds().

-spec starts() -> pos_integer().
starts() -> drone_starts:count().

%% @doc A profile with nothing measured, for an island that has not sat it yet.
%%
%% ⚠ ZEROS RATHER THAN AN ABSENT KEY. CHARTER.md rule 4: a capacity that was
%% never exercised is not evidence of anything, so a reader must be able to tell
%% "sat it and lost everything" from "has not sat it". `starts' being non-zero
%% while every rung is zero is the first; this shape with `starts' present is
%% what makes the distinction expressible at all.
-spec empty() -> profile().
empty() ->
    Z = lists:duplicate(length(rungs()), 0),
    #{rungs => rungs(), wins => Z, draws => Z, losses => Z, starts => 0}.

%% @doc Sit the whole exam.
-spec sit(drone_genome:genome()) -> {ok, profile()} | {error, term()}.
sit(Genome) -> sit(Genome, #{}).

%% @doc As above, over a subset of the starts, for a caller that wants a cheaper
%% reading.
%%
%% ⚠ A PARTIAL RUN REPORTS THE COUNT IT ACTUALLY RAN, so a reader can never
%% mistake a cheap reading for a full one. Silent truncation reads as complete
%% coverage when it is not.
-spec sit(drone_genome:genome(), map()) -> {ok, profile()} | {error, term()}.
sit(Genome, Opts) -> admitted(drone_genome:validate(Genome), Genome, Opts).

admitted({error, _} = E, _G, _Opts) -> E;
admitted(ok, Genome, Opts) ->
    N = min(maps:get(starts, Opts, starts()), starts()),
    Tallies = [rung(Genome, Kind, N) || Kind <- rungs()],
    {ok, #{rungs => rungs(),
           wins => [W || {W, _D, _L} <- Tallies],
           draws => [D || {_W, D, _L} <- Tallies],
           losses => [L || {_W, _D, L} <- Tallies],
           starts => N}}.

rung(Genome, Kind, N) ->
    lists:foldl(fun (I, Acc) -> tally(one(Genome, Kind, I), Acc) end,
                {0, 0, 0}, lists:seq(0, N - 1)).

tally(attacker, {W, D, L}) -> {W + 1, D, L};
tally(draw, {W, D, L}) -> {W, D + 1, L};
tally(defender, {W, D, L}) -> {W, D, L + 1}.

%% ⚠ THE GENOME FLIES AS THE ATTACKER, ONE SEAT ONLY, AND THAT IS JUSTIFIED BY A
%% TEST RATHER THAN ASSUMED. `drone_starts:place/3` is symmetric under swapping
%% the sides in a one-against-one, so the second seat would cost twice the time
%% for the same numbers. `benchmark_tests' asserts the symmetry, so the day it
%% stops holding, this stops being justified and a test says so.
one(Genome, Kind, Index) ->
    {ok, Pilot} = engagement:controller(Genome),
    {ok, Drill} = engagement:controller(Kind),
    Placed = drone_starts:place(1, 1, Index),
    [{AttackerId, _, _, _, _, _}, {DefenderId, _, _, _, _, _}] = Placed,
    Result = engagement:run(airspace:new(Placed),
                            #{AttackerId => Pilot, DefenderId => Drill}),
    maps:get(winner, Result).
