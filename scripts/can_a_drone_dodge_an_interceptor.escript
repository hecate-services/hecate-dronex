#!/usr/bin/env escript
%%! -sname dronex_dodge
%%
%% Launch one interceptor at a fleeing target and ask whether it connects, as a
%% function of the range it was launched from.
%%
%% ==========================================================================
%% ⚠ THE CRITERION IS STATED HERE, BEFORE THE MEASUREMENT, AND IT CAN FAIL
%% ==========================================================================
%%
%% `DESIGN_THE_AIRSPACE.md' claims a specific thing about the two weapons:
%%
%%     the release rewards closing, the interceptor rewards seeing first
%%
%% and, of the interceptor specifically, that its turn radius is deliberately
%% worse than a drone's so that "a target that sees it coming and turns hard at
%% close quarters can beat it, and one engaged at range cannot".
%%
%% That is a claim about a GRADIENT. If the hit rate is flat in range, carrying
%% two weapons is not a decision and the design's own argument for the second one
%% is false.
%%
%% So, fixed in advance:
%%
%%   VIABLE if   hit rate at long range      >= 50%
%%         and   hit rate at close range     =< 40%
%%         and   the gap between them        >= 40 points
%%
%% ⚠⚠ IF NO SETTING MEETS THAT, THE CONSTANTS ARE NOT THE PROBLEM AND THE DESIGN
%% IS. Charter rule 3 forbids picking whichever value produced a number somebody
%% liked, and this script exists to make the whole shape visible rather than one
%% arm of it.
%%
%% Usage:
%%   ERL_LIBS=$PWD/_build/default/lib scripts/can_a_drone_dodge_an_interceptor.escript

%% ⚠ THE RECORD, NOT `element/2', AND THIS SCRIPT GOT IT WRONG BEFORE IT GOT IT
%% RIGHT. A hand-counted field offset read `battery' where it meant `health',
%% 7,920,000 where it meant 10,000, and every comparison came out false. That is
%% the same trap the trainer hit and fixed with accessors, repeated in a script
%% because a script felt too small to bother.
-include_lib("hecate_dronex/include/airspace.hrl").

-define(M, 20480).

main(_Args) ->
    io:format("~nOne interceptor, launched at a fleeing target, over ~p starts~n",
              [starts()]),
    io:format("per range. The target runs the `evader' drill: turn away and run.~n~n"),
    limits(),
    io:format("  ~-10s ~-10s ~8s ~8s ~8s   ~s~n",
              ["range", "evasion", "hit", "missed", "rate", ""]),
    Rows = [row(R, E) || E <- evasions(), R <- ranges()],
    [io:format("  ~-10s ~-10s ~8b ~8b ~7b%   ~s~n",
               [integer_to_list(R) ++ " m", atom_to_list(E), H, M, Pc, bar(Pc)])
     || {R, E, H, M, Pc} <- Rows],
    io:format("~n"),
    verdict(Rows),
    ok.

ranges() -> [30, 50, 100, 200, 300, 450].

%% ⚠ TWO EVASIONS, BECAUSE THE FIRST VERSION MEASURED ONLY ONE AND IT WAS THE
%% WRONG ONE. It used the `evader' drill, which turns away once and then runs
%% straight, and running straight from a faster pursuer keeps you dead centre in
%% its seeker for the whole flight. That is not a dodge, it is a delay, and it
%% reported 100% at every range as if the weapon were unbeatable.
%%
%% `break' is what the design actually claims a drone can do: turn at the maximum
%% rate continuously, so the missile's worse turn radius makes it overshoot. The
%% comparison between the two rows IS the finding.
evasions() -> [run, break].

starts() -> 24.

limits() ->
    #{interceptor_speed := S, interceptor_turn := T, interceptor_ttl := Ttl,
      max_accel := A, drag_div := Div, magazine := Mag} = airspace:limits(),
    Ds = fixed:isqrt(A * Div),
    %% ⚠ ANGULAR RATE IS THE QUANTITY THAT DECIDES A TURNING FIGHT, and it is
    %% `a / v', not `v / r'. A faster missile at the same acceleration is LESS
    %% agile. Printed in thousandths of a radian per second because everything
    %% on this path is an integer.
    io:format("  interceptor  ~p m/s, turn radius about ~p m, rate ~p.~3.10.0b rad/s, ~p s~n",
              [S div 1024, S * S div T div ?M,
               rate_whole(T, S), rate_frac(T, S), Ttl div 20]),
    io:format("  drone        ~p m/s, turn radius about ~p m, rate ~p.~3.10.0b rad/s~n",
              [Ds div 1024, Ds * Ds div A div ?M,
               rate_whole(A, Ds), rate_frac(A, Ds)]),
    io:format("  magazine     ~p~n~n", [Mag]).

%% a / v, in units that cancel to radians per second: acceleration is per tick
%% squared and velocity per tick, so the ratio is per tick, times 20 ticks.
milli_rate(A, V) -> A * 20 * 1000 div V.

rate_whole(A, V) -> milli_rate(A, V) div 1000.
rate_frac(A, V) -> milli_rate(A, V) rem 1000.

%% ⚠ THE SHOOTER FIRES ONCE AND THEN DOES NOTHING. This measures the WEAPON, not
%% a duel: a shooter that kept manoeuvring would fold its own flying skill into
%% the number and the answer would be about controllers rather than about the
%% interceptor's guidance.
row(RangeM, Evasion) ->
    Outcomes = [one(RangeM, I, Evasion) || I <- lists:seq(0, starts() - 1)],
    Hit = length([x || O <- Outcomes, O =:= hit]),
    Missed = length(Outcomes) - Hit,
    {RangeM, Evasion, Hit, Missed, Hit * 100 div length(Outcomes)}.

%% ⚠ A HIT IS DAMAGE, NOT A DEATH, AND THE FIRST VERSION OF THIS PROBE GOT THAT
%% WRONG. One interceptor does half a drone's health, so a single launch can
%% never kill and "did the target survive" is ALWAYS yes. That probe reported a
%% clean 0% at every range and printed a confident verdict saying the design was
%% wrong. It was measuring the wrong quantity, and a wrong quantity measured
%% carefully gives a uniform, plausible, entirely false answer.
one(RangeM, Index, Evasion) ->
    Arena = placed(RangeM, Index),
    [{AId, _, _, _, _, _}, {DId, _, _, _, _, _}] = entrants(RangeM, Index),
    Final = fly(Arena, #{AId => hold(), DId => evade(Evasion, Index)}, ttl() + 40),
    struck(hurt(Final, DId)).

%% The shooter holds station: this measures the WEAPON, and a shooter that kept
%% manoeuvring would fold its own flying into the number.
hold() -> {fixed_intent, #intent{thrust_vert = gravity()}}.

%% `run' is what the evader drill does: point away, full thrust, straight.
%% `break' is a continuous maximum-rate turn, which is what forces a pursuer with
%% a worse turn radius to overshoot. The direction alternates with the index so
%% the answer is not about one handedness.
evade(run, _Index) -> {drill, drone_drills:init(evader)};
evade(break, Index) ->
    #{max_accel := A, max_yaw_rate := R, gravity := G} = airspace:limits(),
    Rate = case Index rem 2 of 0 -> R; _ -> -R end,
    {fixed_intent, #intent{thrust_fwd = A * 3 div 4, thrust_vert = G, yaw_rate = Rate}}.

%% The shooter is nose-on to the target, because a launch needs a lock and a lock
%% needs the target inside the seeker cone. Varying the index rotates the pair
%% and shifts the target's altitude, so a range is not one geometry repeated.
entrants(RangeM, Index) ->
    Angle = (Index * 256) div starts(),
    Cx = 500 * ?M,
    Cy = 500 * ?M,
    Z = (80 + (Index rem 4) * 40) * ?M,
    Tx = Cx + RangeM * ?M * cos(Angle) div 32768,
    Ty = Cy + RangeM * ?M * sin(Angle) div 32768,
    [{{attacker, 1}, attacker, Cx, Cy, Z, Angle},
     {{defender, 1}, defender, Tx, Ty, Z, Angle}].

cos(A) -> fixed:cos(A).
sin(A) -> fixed:sin(A).

%% The shooter launches on tick one and the engine handles the rest: an
%% interceptor already in flight keeps steering whatever its owner does.
placed(RangeM, Index) ->
    A0 = airspace:new(entrants(RangeM, Index)),
    airspace:step(A0, #{{attacker, 1} => launch()}).

launch() ->
    %% Built directly rather than through a controller, because a controller would
    %% have to be good enough to fire and that is a different measurement.
    #intent{thrust_vert = gravity(), launch = 1}.

gravity() ->
    #{gravity := G} = airspace:limits(),
    G.

%% Stepped here rather than through `engagement:run/2', because the engagement
%% ends when a side is out and neither side is: the shooter hovers and the target
%% runs. What is wanted is the interceptor's whole flight.
fly(A, _Cs, 0) -> A;
fly(A, Cs, N) -> fly(stepped(A, Cs), Cs, N - 1).

stepped(A, Cs) ->
    Intents = maps:from_list([{Id, command(Id, Cs, A)} || Id <- ids(A)]),
    airspace:step(A, Intents).

ids(A) -> [D#drone.id || D <- airspace:drones(A)].

command(Id, Cs, A) -> asked(maps:get(Id, Cs), Id, A).

asked({fixed_intent, I}, _Id, _A) -> I;
asked({drill, D}, Id, A) ->
    Self = airspace:drone(A, Id),
    Others = [O || O <- airspace:drones(A), O#drone.id =/= Id],
    {I, _} = drone_drills:act(D, Self, Others, []),
    I.

ttl() ->
    #{interceptor_ttl := T} = airspace:limits(),
    T.

hurt(A, Id) -> (airspace:drone(A, Id))#drone.health.

struck(H) -> below(H < start_health()).

start_health() ->
    #{start_health := H} = airspace:limits(),
    H.

below(true) -> hit;
below(false) -> missed.

bar(Pc) -> lists:duplicate(Pc div 5, $#).

%%==============================================================================
%% The verdict
%%==============================================================================

%% ⚠ THE MACHINE-READABLE LINE IS THE CONTRACT WITH THE SWEEP, and it exists
%% because parsing the prose above it went wrong twice. Erlang's `io:format' does
%% not treat `%%' as an escape, so the human lines carry a doubled percent sign
%% that no obvious pattern matches; before that, a pattern taking the first
%% number on each line reported the THRESHOLDS back as if they were results, and
%% a whole sweep of identical rows looked like a flat finding.
%%
%% A script that reads another script's prose is a mirror of its formatting.
%% ⚠ THE CRITERION IS READ OFF THE `break' ROWS, because the claim is about a
%% target that turns hard. The `run' rows are printed beside them so the
%% difference between the two is visible rather than assumed.
verdict(Rows) ->
    Close = rate(Rows, 50),
    Long = rate(Rows, 300),
    Gap = Long - Close,
    Viable = Long >= 50 andalso Close =< 40 andalso Gap >= 40,
    io:format("  criterion, fixed before the run:~n"),
    io:format("    long range (300 m) hit rate at least 50   ->  ~p  ~s~n",
              [Long, pass(Long >= 50)]),
    io:format("    close range (50 m) hit rate at most 40    ->  ~p  ~s~n",
              [Close, pass(Close =< 40)]),
    io:format("    gap between them at least 40 points       ->  ~p  ~s~n",
              [Gap, pass(Gap >= 40)]),
    io:format("~n  ~s~n", [overall(Viable)]),
    io:format("RESULT close=~p long=~p gap=~p viable=~p~n", [Close, Long, Gap, Viable]).

rate(Rows, R) -> hd([Pc || {Range, break, _H, _M, Pc} <- Rows, Range =:= R]).

pass(true) -> "PASS";
pass(false) -> "FAIL".

overall(true) ->
    "VIABLE: the interceptor rewards seeing first and closing is a defence.";
overall(false) ->
    "NOT VIABLE at these constants. The design claims a range gradient this "
    "weapon does not have.".
