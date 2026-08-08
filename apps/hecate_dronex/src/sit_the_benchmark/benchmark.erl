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

-export([sit/1, sit/2, rungs/0, rungs/1, starts/0, empty/0, empty/1]).
-export([curriculum_ladder/0, held_out_ladder/0]).

-export_type([profile/0]).

-type profile() :: #{rungs := [atom()],
                     wins := [non_neg_integer()],
                     draws := [non_neg_integer()],
                     losses := [non_neg_integer()],
                     %% ⚠ NON-NEG RATHER THAN POSITIVE, AND DIALYZER CAUGHT THE
                     %% DIFFERENCE. Zero starts is `empty/0': an island that has
                     %% not sat the exam. That is the whole reason the shape
                     %% exists, so the type has to be able to say it.
                     starts := non_neg_integer()}.

%% @doc The curriculum ladder: the trainer's scripted opponents.
%%
%% ⚠⚠⚠ THIS IS NOT A HELD-OUT EXAM AND NEVER WAS, WHICH TOOK UNTIL 2026-08-08 TO
%% NOTICE. `trainer:opponents/1' is `drone_drills:kinds() ++ roster', so these six
%% are inside the training distribution, over the same 48 start geometries, and
%% have been since the trainer was written. Between about 11% and 28% of breeding
%% rounds per island draw at least one of them as an opponent. `REGISTER I.22'
%% has the arithmetic and the correction to `D.7', whose headline sentence was
%% "the population improved against an exam it never trains on".
%%
%% It keeps being published, because a number withdrawn leaves a hole in a
%% history and a number labelled leaves a record. What may be read off it is
%% "performance against the curriculum", which is a real quantity and is not
%% improvement.
-spec curriculum_ladder() -> module().
curriculum_ladder() -> drone_drills.

%% @doc The held-out ladder: six opponents nothing trains against.
%%
%% ⚠ THE SEPARATION IS ENFORCED BY `trials_tests', not by this comment. The first
%% exam was held out by assertion in four documents and by nothing in the code.
-spec held_out_ladder() -> module().
held_out_ladder() -> drone_trials.

%% @doc The rungs of the curriculum ladder. Unchanged, so every caller that had
%% one exam still has that one.
-spec rungs() -> [atom()].
rungs() -> rungs(curriculum_ladder()).

-spec rungs(module()) -> [atom()].
rungs(Ladder) -> Ladder:kinds().

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
empty() -> empty(curriculum_ladder()).

-spec empty(module()) -> profile().
empty(Ladder) ->
    Z = lists:duplicate(length(rungs(Ladder)), 0),
    #{rungs => rungs(Ladder), wins => Z, draws => Z, losses => Z, starts => 0}.

%% @doc Sit the whole exam.
-spec sit(drone_genome:genome()) -> {ok, profile()} | {error, term()}.
sit(Genome) -> sit(Genome, #{}).

%% @doc As above, over a subset of the starts, for a caller that wants a cheaper
%% reading.
%%
%% ⚠ A PARTIAL RUN REPORTS THE COUNT IT ACTUALLY RAN, so a reader can never
%% mistake a cheap reading for a full one. Silent truncation reads as complete
%% coverage when it is not.
%% ⚠ `ladder' IS AN OPTION AND ITS DEFAULT IS THE CURRICULUM, so every existing
%% caller keeps the exam it had and the profile it publishes does not change
%% shape. The profile carries its own `rungs' names, so which ladder produced a
%% reading is a property of the reading rather than something a reader has to
%% remember.
-spec sit(drone_genome:genome(), map()) -> {ok, profile()} | {error, term()}.
sit(Genome, Opts) -> admitted(drone_genome:validate(Genome), Genome, Opts).

admitted({error, _} = E, _G, _Opts) -> E;
admitted(ok, Genome, Opts) ->
    Ladder = maps:get(ladder, Opts, curriculum_ladder()),
    N = min(maps:get(starts, Opts, starts()), starts()),
    Tallies = [rung(Genome, Ladder, Kind, N) || Kind <- rungs(Ladder)],
    {ok, #{rungs => rungs(Ladder),
           wins => [W || {W, _D, _L} <- Tallies],
           draws => [D || {_W, D, _L} <- Tallies],
           losses => [L || {_W, _D, L} <- Tallies],
           starts => N}}.

rung(Genome, Ladder, Kind, N) ->
    lists:foldl(fun (I, Acc) -> tally(one(Genome, Ladder, Kind, I), Acc) end,
                {0, 0, 0}, lists:seq(0, N - 1)).

tally(attacker, {W, D, L}) -> {W + 1, D, L};
tally(draw, {W, D, L}) -> {W, D + 1, L};
tally(defender, {W, D, L}) -> {W, D, L + 1}.

%% ⚠ THE GENOME FLIES AS THE ATTACKER, ONE SEAT ONLY, AND THAT IS JUSTIFIED BY A
%% TEST RATHER THAN ASSUMED. `drone_starts:place/3` is symmetric under swapping
%% the sides in a one-against-one, so the second seat would cost twice the time
%% for the same numbers. `benchmark_tests' asserts the symmetry, so the day it
%% stops holding, this stops being justified and a test says so.
one(Genome, Ladder, Kind, Index) ->
    {ok, Pilot} = engagement:controller(Genome),
    {ok, Drill} = engagement:controller({Ladder, Kind}),
    Placed = drone_starts:place(1, 1, Index),
    [{AttackerId, _, _, _, _, _}, {DefenderId, _, _, _, _, _}] = Placed,
    %% ⚠ SPELLED OUT, NOT LEFT TO THE DEFAULT. The benchmark is an away game
    %% ALWAYS: drills, fixed geometry, no sensors, no cueing, ground bank forced
    %% to zero. It measures the CONTROLLER, and a network here would mean the
    %% frozen ladder scored an island's terrain instead — every rung would move
    %% the day the placement changed, and the one fixed thing in the system would
    %% stop being fixed. Relying on `engagement:run/2' defaulting to no network
    %% would leave that commitment resting on a default somebody could flip.
    Result = engagement:run(airspace:new(Placed),
                            #{AttackerId => Pilot, DefenderId => Drill},
                            #{network => ground_network:none()}),
    maps:get(winner, Result).
