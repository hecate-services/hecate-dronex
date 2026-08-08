%% @doc The scripted opponents an island is measured against. PURE.
%%
%% ⚠⚠⚠⚠ THIS IS THE CURRICULUM, NOT THE EXAM, AND THE HEADER SAID OTHERWISE FOR
%% MONTHS. It read "nothing ever trains against them". `trainer:opponents/1' has
%% returned `drone_drills:kinds() ++ roster' since the trainer was written, so
%% these six ARE what the islands breed against, between about 11% and 28% of
%% rounds each. Reusing them as `benchmark:rungs/0' put the exam inside its own
%% training distribution, over the same 48 start geometries. `REGISTER I.22' has
%% the arithmetic and the correction to `D.5'.
%%
%% The held-out exam is `drone_trials', which nothing trains against and which
%% `trials_tests' keeps that way by assertion rather than by comment.
%%
%% These stay exactly as they are. They are a good curriculum: a ladder from
%% trivial to hard, graded on the axis `D.4' measured, and they never change.
%% What may be read off them is performance against the curriculum, which is a
%% real quantity and is not improvement.
%%
%% Insight 054: a benchmark that is not FIXED and GRADED saturates and goes
%% silently blind, and its specific finding was that a weak reference set missed
%% roughly 31 of about 35 units of progress.
%%
%% ==========================================================================
%% ⚠ A DRILL READS THE SAME SENSOR VECTOR AN EVOLVED CONTROLLER READS
%% ==========================================================================
%%
%% It would be far easier to write these against the arena directly. It would
%% also make every benchmark number a measurement against an opponent with better
%% eyes: a drill that could see behind itself, or past 600 m, would be beating
%% genomes that cannot. `drone_senses:sense/3` is the same call `drone_pilot`
%% makes, so the limit is structural rather than promised.
%%
%% ==========================================================================
%% ⚠ EACH ONE IS A BEHAVIOUR, NOT A TACTIC
%% ==========================================================================
%%
%% None of these is meant to be good. They are rungs: a thing to be measured
%% against, each isolating one demand. A drill that played well would make the
%% benchmark a match rather than a ruler, and its score would stop meaning
%% anything the day somebody improved it.
%%
%% ⚠⚠ THE SET IS FROZEN ONCE ANYTHING HAS BEEN BRED AGAINST IT. A ladder adjusted
%% after training has started measures the adjustment. A new ladder is added
%% beside this one with its own name and its own history; this one keeps being
%% published.
-module(drone_drills).

-include("airspace.hrl").

-export([kinds/0, init/1, act/4, describe/1]).

-export_type([drill/0, kind/0]).

-type kind() :: hoverer | orbiter | evader | sniper | chaser | duellist.
-type drill() :: {kind(), non_neg_integer()}.

%% ⚠ IN ORDER OF DEMAND, AND THE ORDER IS PART OF THE INSTRUMENT. A profile that
%% is won at the bottom and lost at the top says where a population is; one whose
%% rungs are shuffled says nothing, because a benchmark reads as a curve.
%%
%% ⚠⚠ THE FIRST LADDER WAS MEASURED AND DID NOT GRADE. Register `D.4'. It was
%% hoverer, climber, orbiter, evader, jinker, chaser: six drills that differed
%% only in how they MOVED, and only the last of which could shoot. Over 48 starts
%% two random controllers scored 11/8/10/13/11/12 and 32/36/34/31/33/23, so five
%% of the six rungs were one rung repeated and the instrument was blind across
%% most of its range. Insight 054 predicts exactly that and is the reason this was
%% measured before anything was bred rather than after.
%%
%% The axis that measurably separated was whether the opponent SHOOTS. So the
%% ladder grades on that, with movement as the secondary axis: three passive
%% rungs, then three armed ones.
%%
%% ⚠⚠⚠ AND THE ORDER IS MEASURED RATHER THAN GUESSED, WHICH IS THE SECOND HALF OF
%% `D.4'. The armed rungs were first written as sniper, chaser, duellist, on the
%% assumption that a stationary shooter is the easiest of the three. It is the
%% HARDEST, by a wide margin: over 48 starts the two random controllers scored
%% 3 and 2 against the sniper, against 22 and 8 for the chaser. Closing costs
%% aim, and a drill that only shoots never pays it. So the order below is the
%% order the measurement put them in, and a rung order asserted rather than
%% measured is a curve that reads backwards.
%%
%% ⚠⚠⚠ THIS IS THE LAST TIME THE LADDER MAY CHANGE. Nothing has been bred against
%% it yet. Once something has, a ladder adjusted afterwards measures the
%% adjustment, and a NEW ladder is added beside this one with its own name and
%% its own history while this one keeps being published.
-define(KINDS, [hoverer, orbiter, evader, chaser, duellist, sniper]).

%% How often the two drills with a period reverse. 40 ticks is 2 seconds, which is
%% long enough to build speed and short enough that an engagement sees many.
-define(PERIOD, 40).

-spec kinds() -> [kind()].
kinds() -> ?KINDS.

-spec describe(kind()) -> binary().
describe(hoverer) -> <<"holds station, unarmed. Can you kill anything at all">>;
describe(orbiter) -> <<"flies a circle, unarmed. Can you kill something moving">>;
describe(evader) -> <<"turns away and runs, unarmed. Can you catch it">>;
describe(chaser) -> <<"closes and shoots. Can you win a fight it chose">>;
describe(duellist) -> <<"closes, shoots, and breaks off hurt. Has to be finished">>;
describe(sniper) -> <<"holds station and shoots. The hardest: it never pays for closing">>.

-spec init(kind()) -> drill().
init(Kind) -> {Kind, 0}.

%% @doc One tick. Same shape as `drone_pilot:act/4`, deliberately, so a host can
%% drive a genome and a drill through one call.
-spec act(drill(), #drone{}, [#drone{}], [integer()]) -> {#intent{}, drill()}.
act({Kind, N}, #drone{} = Self, Others, Comms) ->
    {fly(Kind, N, drone_senses:sense(Self, Others, Comms)), {Kind, N + 1}}.

%%==============================================================================
%% The rungs
%%==============================================================================

%% Rung 1. Commands exactly enough thrust to cancel gravity, which holds altitude
%% to the unit, and nothing else.
fly(hoverer, _N, _V) -> #intent{thrust_vert = gravity()};

%% Rung 2. Constant forward thrust and a constant turn, which is a circle, while
%% weaving vertically. Moving in three axes and still unarmed.
fly(orbiter, N, _V) ->
    #intent{thrust_fwd = accel() * 3 div 4, thrust_vert = gravity() + climb(N),
            yaw_rate = 6};

%% Rung 3. Turns away from the nearest hostile and runs, weaving as it goes. It
%% never shoots, so it cannot be out-shot: it has to be caught.
fly(evader, N, V) -> running(drone_senses:nearest_hostile(V), N);

%% Rung 4. Holds station and shoots. The first rung that can kill, and the one
%% that isolates working under fire from chasing something down.
fly(sniper, _N, V) -> shooting(drone_senses:nearest_hostile(V), still);

%% Rung 5. Closes on the nearest hostile and shoots.
fly(chaser, _N, V) -> shooting(drone_senses:nearest_hostile(V), closing);

%% Rung 6. Closes and shoots until it is hurt, then breaks off and runs. It has
%% to be FINISHED rather than merely beaten, which is the hardest thing on the
%% ladder and the only rung that uses the withdrawal mechanism against you.
fly(duellist, N, V) ->
    duelling(drone_senses:nearest_hostile(V), drone_senses:self_reading(V), N).

%%==============================================================================
%% Pieces
%%==============================================================================

%% A triangle wave from the drill's own counter. Deterministic, and it needs no
%% clock and no generator, which is what keeps a benchmark reproducible.
climb(N) -> phase(N rem (2 * ?PERIOD)).

phase(P) when P < ?PERIOD -> accel() div 4;
phase(_P) -> -(accel() div 4).

%% Nothing in sight: hold station rather than wander. A drill that drifted would
%% make its own rung's difficulty depend on where it happened to end up.
running(undefined, _N) -> #intent{thrust_vert = gravity()};
running(#{bearing_sin := S}, N) ->
    #intent{thrust_fwd = accel() * 3 div 4, thrust_vert = gravity() + climb(N),
            yaw_rate = turn(S, away)}.

shooting(undefined, _Move) -> #intent{thrust_vert = gravity()};
shooting(#{bearing_sin := S, bearing_cos := C, range := R}, Move) ->
    #intent{thrust_fwd = forward(Move), thrust_vert = gravity(),
            yaw_rate = turn(S, toward),
            release = trigger(C > 0.9 andalso R < 0.05),
            launch = trigger(C > 0.9 andalso R >= 0.05)}.

forward(still) -> 0;
forward(closing) -> accel() * 3 div 4.

%% Hurt is half health. Below it the duellist stops fighting and runs, which is
%% the behaviour the withdrawal mechanism exists for and the only rung that makes
%% a controller finish what it started.
duelling(Seen, #{health := H}, _N) when H > 0.5 -> shooting(Seen, closing);
duelling(Seen, _Self, N) -> running(Seen, N).

%% Turn toward a contact by steering in the direction its bearing sits, and away
%% by steering the other way. The sine is signed, so the sign IS the direction
%% and no comparison against an angle is needed.
turn(S, toward) when S > 0.0 -> max_turn();
turn(S, toward) when S < 0.0 -> -max_turn();
turn(S, away) when S > 0.0 -> -max_turn();
turn(S, away) when S < 0.0 -> max_turn();
turn(_S, toward) -> 0;
turn(_S, away) -> max_turn().

trigger(true) -> 1;
trigger(false) -> 0.

gravity() ->
    #{gravity := G} = airspace:limits(),
    G.

accel() ->
    #{max_accel := A} = airspace:limits(),
    A.

max_turn() ->
    #{max_yaw_rate := R} = airspace:limits(),
    R.
