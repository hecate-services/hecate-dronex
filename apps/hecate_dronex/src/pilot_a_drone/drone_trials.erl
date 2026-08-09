%% @doc The HELD-OUT ladder. Six opponents that shoot AND close. PURE.
%%
%% THIS EXISTS BECAUSE THE FROZEN LADDER IS BOTH SATURATED AND CONTAMINATED, AND
%% THE SECOND HALF OF THAT IS THE PART NOBODY HAD NOTICED.
%%
%% ==========================================================================
%% ⚠ WHAT `drone_drills' IS FOR, AND WHY THIS IS A DIFFERENT MODULE
%% ==========================================================================
%%
%% `CHARTER.md' asks an island for two things that were being served by one set
%% of six behaviours:
%%
%%   - an OPPONENT SET, which is "scripted drills, its own past champions, and
%%     every foreign genome it has ever been attacked by", and which the trainer
%%     breeds against
%%   - a FROZEN BENCHMARK "it never trains against, which is the only number on
%%     this island that may be called improvement"
%%
%% Those two are consistent only if the scripted drills in the first are not the
%% rungs of the second. They were the same six. `trainer:opponents/1' returns
%% `drone_drills:kinds() ++ roster', and `benchmark:rungs/0' returned that same
%% `drone_drills:kinds()', so the exam sat inside the training distribution, over
%% the same 48 start geometries, and had done since the trainer was written.
%% `REGISTER I.22' has the measured leak.
%%
%% So `drone_drills' keeps its job, which was always the curriculum, and this is
%% the exam. The two are kept apart by a TEST rather than by a comment:
%% `trials_tests' asserts that no kind here ever appears in
%% `trainer:opponents/1'. A promise that the compiler cannot check is the thing
%% that failed the first time.
%%
%% ==========================================================================
%% ⚠⚠ EVERY RUNG IS THE CHASER PLUS EXACTLY ONE COMPETENCE
%% ==========================================================================
%%
%% `drone_drills' graded on whether the opponent SHOOTS, which is what measurably
%% separated random controllers at `REGISTER D.4'. That axis is spent: four of
%% five islands score 47 or 48 of 48 on all six rungs. `D.16' says the surviving
%% deficit is against opponents that shoot AND close, so every rung here does
%% both, and they differ from each other in ONE added competence each:
%%
%%   bruiser   closes in three dimensions      you cannot climb away from it
%%   harrier   side-slips while closing        it does not fly the line it aims
%%   circler   holds a range it chose          you cannot out-run or rush it
%%   swooper   attacks from above              it fights where you are not looking
%%   leader    aims where you will be          a straight line is not an escape
%%   marksman  holds fire for a shot worth 2   it does not waste a magazine
%%
%% The base is `drone_drills:chaser' in every case: close at three quarters
%% thrust, turn toward, release inside 30 m and launch out to the weapon's reach.
%% One addition per rung is what makes a profile readable. A rung that stacked
%% three improvements would report a deficit without naming it, and the point of a
%% ladder is that a failure says WHICH demand was not met.
%%
%% ==========================================================================
%% ⚠⚠⚠ A SEVENTH RUNG WAS WRITTEN AND MEASURED OUT, WHICH IS WHY MEASURING FIRST
%% IS THE RULE
%% ==========================================================================
%%
%% `hunter' closed and shot exactly as `bruiser' does, and additionally came
%% LOOKING when the contact left its 120 degree cone: every rung in
%% `drone_drills' holds station when its cone is empty, so breaking line of sight
%% defeats all six of them and always did. It is the one demand the old ladder
%% could not make, and it looked like the best rung here.
%%
%% Over 48 starts against five live champions it returned 48, 35, 6, 48, 48 wins.
%% So does `bruiser'. Not close to it: the same numbers, champion for champion,
%% down to the single draw on beam01. The added competence never fired once,
%% because a champion bred to fight never breaks contact, and a rung whose
%% difference is unreachable is not a rung. Two identical columns on a profile
%% are worse than one, because they read as corroboration.
%%
%% That is `REGISTER D.4' exactly: its first ladder had five of six rungs turn
%% out to be one rung repeated, and only pointing known controllers at it
%% revealed that. The lesson survives the specific case, and a re-acquiring
%% opponent is worth adding to a LATER ladder if a population ever learns to run.
%%
%% ==========================================================================
%% ⚠⚠⚠⚠ WHAT IT MEASURES, AND WHERE IT IS BLIND. BOTH, BEFORE IT IS USED
%% ==========================================================================
%%
%% Measured over 48 starts against the five live champions and against a null and
%% eight random controllers, before anything was bred against it.
%%
%% IT WORKS AT THE TOP. Champion totals span 120 to 276 of 288, where the
%% curriculum ladder's fleet-wide spread is two points. `swooper' and `leader'
%% separate all five champions from each other AND from the best random
%% controller, which is what an instrument is for.
%%
%% ⚠ IT IS BLIND AT THE BOTTOM, AND THAT IS STATED HERE RATHER THAN LEFT TO BE
%% FOUND. Three of eight random controllers sweep `circler', `bruiser',
%% `marksman' and very nearly `harrier'. Those four rungs therefore separate a
%% champion from a crash and little else, which the curriculum ladder already
%% did. `REGISTER D.6' raised exactly this against the first ladder; the
%% difference is that there the HARDEST rung was maxed by random genomes and here
%% the hardest two are not. The resolution is real and it lives in the top third.
%%
%% ⚠⚠ SO A READING OFF THE BOTTOM FOUR MEANS LESS THAN A READING OFF THE TOP TWO,
%% and anybody quoting a total across all six is averaging an instrument with a
%% ruler. That is why a profile is never summed.
%%
%% Now that it is measured, the set is FROZEN. Once anything has been bred
%% against it, a further ladder is added beside it rather than this one being
%% adjusted, which is the same rule `drone_drills' carries and the reason it
%% still exists.
-module(drone_trials).

-include("airspace.hrl").

-export([kinds/0, init/1, act/4, describe/1]).

-export_type([trial/0, kind/0]).

-type kind() :: bruiser | harrier | circler | swooper | leader | marksman.

%% ⚠ THE STATE CARRIES A MEMORY AND `drone_drills' DOES NOT, which is the whole
%% difference between anticipating and reacting. `leader' needs the previous
%% bearing to know which way a contact is drifting, and `hunter' needs the last
%% side it was seen on to know which way to look. Neither is derivable from one
%% frame, and neither is privileged information: a real airframe remembers what
%% its own sensor said a twentieth of a second ago.
-type trial() :: {kind(), non_neg_integer(), memory()}.
-type memory() :: #{last_sin := float(), last_side := -1 | 0 | 1}.

%% ⚠ THE ORDER IS MEASURED, NOT ASSERTED, AND THE MEASUREMENT MOVED IT. Written
%% order was bruiser, harrier, circler, swooper, leader, on the reasoning that
%% closing in three dimensions is the smallest addition. Over 48 starts against
%% the five live champions, wins out of 240:
%%
%%   circler   227      easiest: a standoff is the one addition a champion
%%   harrier   202      already handles, because it still flies at you
%%   marksman  192
%%   bruiser   185
%%   swooper   139      hardest: the vertical and the lead are where every
%%   leader    130      champion on the fleet still loses
%%
%% So `circler' is the bottom rung and not the third, which is exactly `D.4'
%% happening again: a rung order asserted rather than measured is a curve that
%% reads backwards. Raw output in `measurements/held_out_ladder_48_starts.txt'.
%%
%% ==========================================================================
%% ⚠⚠⚠⚠ AND ALL SIX OF THOSE NUMBERS ARE VOID AS OF 2026-08-09. THE ORDER IS
%% UNKNOWN, NOT WRONG, AND IT CANNOT BE RE-MEASURED YET
%% ==========================================================================
%%
%% They were measured against five champions bred under a guided weapon reaching
%% 600 m, which now reaches 60 m, on a start set that opened at 400 m, which now
%% opens at 800 m. Every one of those champions has since been wiped.
%%
%% ⚠ RE-GRADING NEEDS CONTROLLERS THAT CAN TELL RUNGS APART, AND THERE ARE NONE.
%% A null and five random controllers now win 0 of 48 on every rung here and on
%% every rung of the curriculum, on BOTH start sets — measured that way on
%% purpose, so the geometry and the weapon could be told apart, and it is the
%% weapon. A ladder graded against controllers that all score zero has been
%% asserted, not measured, which is the failure `D.4' names.
%%
%% ⚠⚠ AND IT SAYS SOMETHING ABOUT WHAT THE OLD BOTTOM OF THIS LADDER WAS. The
%% paragraph above admits three of eight random controllers used to sweep
%% `circler', `bruiser' and `marksman'. They did it by holding `launch' high at a
%% target visible and in range from tick zero, with a 600 m interceptor that
%% cannot be dodged. The blindness at the bottom was not that the rungs were too
%% easy. It was that the weapon paid out for nothing.
%%
%% So: re-measure after the first population is bred against these physics, and
%% until then read a profile rung by rung and never as a curve.
-define(KINDS, [circler, harrier, marksman, bruiser, swooper, leader]).

%% How often the weave reverses. 40 ticks is 2 seconds, matching `drone_drills'
%% so that a rung here differs from one there in its competence and not in its
%% tempo.
-define(PERIOD, 40).

%% @doc The range `circler' holds, as a fraction of the 600 m sensor.
%%
%% ⚠ THE CHOICE IS BOUNDED AT BOTH ENDS RATHER THAN PICKED: inside the guided
%% weapon's envelope with margin, and far outside the roughly 15 m where an
%% unguided release is effective. A circler at knife range would be a chaser with
%% extra steps, and one sitting beyond its own weapon would be a hoverer.
%%
%% ⚠⚠ AND IT WAS A LITERAL `0.15' UNTIL 2026-08-09, WHICH BROKE THE RUNG SILENTLY
%% THE HOUR THE WEAPON CHANGED. 0.15 is 90 m. That was comfortably inside a
%% weapon reaching 600 m, and is outside one reaching 60 m — so the circler would
%% have held station beyond its own launch gate, shot nothing for the whole
%% engagement, and become the hoverer its own comment warned about. Nothing would
%% have failed. The rung would just have gone quietly easy, and a benchmark that
%% goes quietly easy is worse than one that breaks.
%%
%% Three quarters of the reach, so the relationship the paragraph above describes
%% survives whatever the weapon becomes. `trials_tests' checks the bounds rather
%% than the number.
standoff() -> drone_senses:reach_fraction() * 0.75.

%% How hard `leader' extrapolates the bearing drift it remembers. Turning is
%% bang-bang at `max_yaw_rate', so this gain does not change how FAST it turns:
%% it changes WHEN it reverses, which is the entire competence being isolated.
-define(LEAD, 3.0).

-spec kinds() -> [kind()].
kinds() -> ?KINDS.

-spec describe(kind()) -> binary().
describe(bruiser) -> <<"closes and shoots in three dimensions. You cannot climb away">>;
describe(harrier) -> <<"closes and shoots while side-slipping. It does not fly the line it aims">>;
describe(circler) -> <<"holds a range it chose and shoots. You cannot out-run it or rush it">>;
describe(swooper) -> <<"climbs above, then dives shooting. It fights where you are not looking">>;
describe(leader) -> <<"closes and shoots where you will be. A straight line is not an escape">>;
describe(marksman) -> <<"closes and holds fire until the shot is worth four. It does not waste a magazine">>.

-spec init(kind()) -> trial().
init(Kind) -> {Kind, 0, #{last_sin => 0.0, last_side => 0}}.

%% @doc One tick. Same shape as `drone_pilot:act/4' and `drone_drills:act/4',
%% deliberately, so one loop drives a genome, a curriculum drill and an exam
%% opponent without knowing which it holds.
-spec act(trial(), #drone{}, [#drone{}], [integer()]) -> {#intent{}, trial()}.
act({Kind, N, Mem}, #drone{} = Self, Others, Comms) ->
    Seen = drone_senses:nearest_hostile(drone_senses:sense(Self, Others, Comms)),
    {fly(Kind, N, Seen, Mem), {Kind, N + 1, kept(Seen, Mem)}}.

%% ⚠ THE CONTACT IS DECODED ONCE PER TICK AND PASSED DOWN. The obvious shape has
%% each rung ask `drone_senses:nearest_hostile/1' for itself, and `harrier' then
%% asks twice and every rung asks a third time to update its memory. An exam is
%% six rungs over 48 starts over thousands of ticks, and it runs on a 1.5 GHz
%% Celeron beside a trainer that is always running.
%%
%% ⚠⚠ AND THE MEMORY IS WRITTEN AFTER THE RUNG HAS FLOWN, WHICH IS WHAT MAKES
%% `leader' WORK AT ALL. It reads `last_sin' expecting the PREVIOUS frame's
%% bearing; writing first would have it compare a bearing against itself and lead
%% by exactly zero, which is a rung that silently degenerates into the chaser it
%% is supposed to improve on.
kept(undefined, Mem) -> Mem;
kept(#{bearing_sin := S}, Mem) -> Mem#{last_sin := S, last_side := side(S)}.

side(S) when S > 0.0 -> 1;
side(S) when S < 0.0 -> -1;
side(_S) -> 0.

%%==============================================================================
%% The rungs
%%==============================================================================

%% Rung 1. The chaser, plus the vertical axis. Every drill in `drone_drills'
%% commands exactly enough vertical thrust to hold its altitude and steers only
%% in yaw, so climbing away from one of them works and always has.
fly(bruiser, _N, Seen, _Mem) ->
    closing_on(Seen, #{vertical => track, forward => full});

%% Rung 2. The chaser, plus a lateral weave. It is the first opponent that does
%% not travel along the line its nose is pointing, so a controller that has
%% learnt to fly at where an enemy is aiming is aiming at where this one is not.
fly(harrier, N, Seen, _Mem) ->
    slipped(closing_on(Seen, #{vertical => hold, forward => full}), Seen, weave(N));

%% Rung 3. The chaser, plus a range it chose. It closes when it is outside 90 m
%% and backs off when it is inside, so neither running away nor charging changes
%% the fight it is offering.
fly(circler, _N, Seen, _Mem) ->
    closing_on(Seen, #{vertical => hold, forward => standoff});

%% Rung 4. The chaser, plus an altitude advantage it takes before it commits. It
%% holds itself above the contact while far, and dives once inside 60 m.
fly(swooper, _N, Seen, _Mem) ->
    closing_on(Seen, #{vertical => above, forward => full});

%% Rung 5. The chaser, plus a lead on its aim. It steers at where the bearing is
%% drifting TO rather than where the contact is, so it reverses its turn before
%% a crossing target has crossed.
fly(leader, _N, Seen, Mem) ->
    closing_on(led(Seen, Mem), #{vertical => hold, forward => full});

%% Rung 6. The chaser, plus fire discipline. The magazine is four interceptors
%% for a whole engagement and never reloads, and two hits kill, so what a
%% controller spends them on decides the fight. Every other rung on both ladders
%% launches at `bearing_cos > 0.9', which is a 26 degree cone at any range out to
%% 600 m, and empties itself early on shots that cannot connect. This one holds
%% until the shot is worth taking.
fly(marksman, _N, Seen, _Mem) ->
    aimed(Seen, closing_on(Seen, #{vertical => hold, forward => full})).

%%==============================================================================
%% Pieces
%%==============================================================================

%% Nothing in sight: hold station. Same convention as `drone_drills', for the
%% five rungs that are not `hunter'. A drill that wandered would make its own
%% rung's difficulty depend on where it happened to drift to.
closing_on(undefined, _How) -> #intent{thrust_vert = gravity()};
closing_on(#{bearing_sin := S, bearing_cos := C, range := R} = Seen, How) ->
    #intent{thrust_fwd = forward(maps:get(forward, How), R),
            thrust_vert = gravity() + vertical(maps:get(vertical, How), Seen),
            yaw_rate = turn(S, toward),
            release = trigger(C > 0.9 andalso R < 0.05),
            %% 0.2 is 120 m, the interceptor's whole reach since 2026-08-09.
            %% Uncapped, as this read until that day, every rung would spend both
            %% of its two shots at four hundred metres and arrive unarmed. Same
            %% change and same reason as `drone_drills:shooting/2'.
            launch = trigger(C > 0.9 andalso R >= 0.05 andalso R =< drone_senses:reach_fraction())}.

forward(full, _R) -> accel() * 3 div 4;
%% Positive outside the standoff, negative inside it. The sign IS the behaviour
%% and no comparison against a state machine is needed.
%%
%% ⚠ THE COMPARISON IS IN THE BODY BECAUSE `standoff/0' IS A FUNCTION NOW. It was
%% the macro `?STANDOFF', which a guard accepts because a macro is a literal by
%% the time the guard sees it. Deriving the value from the weapon is what made it
%% a call, and a call in a guard does not compile. Matching on the boolean keeps
%% the two outcomes as two clauses, which is how the rest of this module reads.
forward(standoff, R) -> closing(R > standoff()).

closing(true) -> accel() * 3 div 4;
closing(false) -> -(accel() div 2).

vertical(hold, _Seen) -> 0;
%% Elevation is the signed vertical offset to the contact, so thrusting along it
%% closes the gap. This is the axis `drone_drills' never uses.
vertical(track, #{elevation := E}) -> round(E * (accel() div 4));
%% Sit above the contact until close enough to commit, then dive on it. 0.1 of
%% the sensor is 60 m.
vertical(above, #{elevation := E, range := R}) when R >= 0.1 ->
    round((E + 0.35) * (accel() div 4));
vertical(above, #{elevation := E}) -> round(E * (accel() div 4)).

%% A triangle wave from the trial's own counter, exactly as `drone_drills:climb/1'
%% builds one. Deterministic, needing no clock and no generator, which is what
%% keeps an exam reproducible.
weave(N) -> phase(N rem (2 * ?PERIOD)).

phase(P) when P < ?PERIOD -> accel() div 3;
phase(_P) -> -(accel() div 3).

%% ⚠ THE WEAVE IS DROPPED WHEN NOTHING IS SEEN, so `harrier' with an empty cone
%% is the same held station as every other rung. Side-slipping at nothing would
%% make it drift, and a drifting opponent's difficulty depends on where it ended
%% up rather than on what it does.
slipped(Intent, undefined, _Lat) -> Intent;
slipped(#intent{} = I, _Seen, Lat) -> I#intent{thrust_lat = Lat}.

%% ⚠ THE LEAD IS APPLIED TO THE BEARING BEFORE THE TURN IS DECIDED, and it can
%% flip the sign. That is the point: turning is bang-bang, so leading cannot make
%% the turn faster and can only make it start earlier.
led(undefined, _Mem) -> undefined;
led(#{bearing_sin := S} = Seen, #{last_sin := Prev}) ->
    Seen#{bearing_sin := clampf(S + ?LEAD * (S - Prev), -1.0, 1.0)}.

%% ⚠ THE AIM GATE REPLACES THE ONE `closing_on/2' ALREADY SET, rather than
%% adding to it, so `marksman' fires strictly less often than the chaser and
%% every shot it does take is inside 11 degrees and inside 90 m. Both halves are
%% the same competence: do not spend a round of two on a shot that cannot
%% connect.
%%
%% ⚠⚠ 0.15 IS 90 m AND IT WAS 0.3, WHICH IS 180 m AND IS NOW BEYOND THE WEAPON.
%% The interceptor reached 600 m until 2026-08-09 and reaches 120 m now, so the
%% old band spent half its shots into empty air — with a magazine of two, that is
%% the whole drone. This rung's identity is that it holds fire longer than the
%% others do, so it keeps the tighter number: everyone else stops at 120 m, the
%% marksman stops at 90 m and its shots connect.
aimed(undefined, Intent) -> Intent;
aimed(#{bearing_cos := C, range := R}, #intent{} = I) ->
    I#intent{release = trigger(C > 0.98 andalso R < 0.05),
             launch = trigger(C > 0.98 andalso R >= 0.05 andalso R =< drone_senses:reach_fraction())}.

%% Turn toward a contact by steering in the direction its bearing sits. The sine
%% is signed, so the sign IS the direction and no comparison against an angle is
%% needed.
turn(S, toward) when S > 0.0 -> max_turn();
turn(S, toward) when S < 0.0 -> -max_turn();
turn(_S, toward) -> 0.

trigger(true) -> 1;
trigger(false) -> 0.

clampf(V, Lo, _Hi) when V < Lo -> Lo;
clampf(V, _Lo, Hi) when V > Hi -> Hi;
clampf(V, _Lo, _Hi) -> V.

gravity() ->
    #{gravity := G} = airspace:limits(),
    G.

accel() ->
    #{max_accel := A} = airspace:limits(),
    A.

max_turn() ->
    #{max_yaw_rate := R} = airspace:limits(),
    R.
