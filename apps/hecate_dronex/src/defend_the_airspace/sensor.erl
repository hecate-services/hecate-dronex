%% @doc What one ground sensor would actually report. PURE and DETERMINISTIC.
%%
%% THIS EXISTS SO AN ISLAND HAS GEOGRAPHY RATHER THAN A BOUNDING BOX.
%%
%% ==========================================================================
%% ⚠ THE BEHAVIOUR PORTS WHOLE FROM THE COUNTER-UAS LINE. THE ARITHMETIC DOES NOT
%% ==========================================================================
%%
%% `dronex_sensor_model' is three arguments and a contact or a miss — ground
%% truth in, this sensor's placement and knobs in, the environment in. Nothing
%% about it is counter-UAS specific and it is the swap point at which a
%% CHARACTERISED REAL SENSOR is dropped in without the consumer noticing.
%%
%% What did not survive the move is every number in the retained
%% `remote_id_sensor_model':
%%
%%   `math:sqrt'   -> `fixed:mag3', because the fight path is integer
%%   `rand:uniform'-> a hash of (sensor, drone, tick), see below
%%   `rand:normal' -> the same
%%   `erlang:system_time(millisecond)' -> the tick
%%
%% That last one is not a style preference. A wall clock inside a fight loop
%% destroys reproducibility, and a raid that cannot be replayed identically by
%% the island that flew into it is a raid nobody can check.
%%
%% ==========================================================================
%% ⚠⚠ RANDOMNESS FROM A HASH, NOT A GENERATOR, AND THAT IS THE WHOLE TRICK
%% ==========================================================================
%%
%% Detection is probabilistic and the engagement loop has no random state to
%% thread — deliberately, because `engagement:run/3' is a pure fold and adding a
%% seed to it would put a mutable thing on the one path that must replay
%% identically everywhere.
%%
%% So the draw is `erlang:phash2({Salt, SensorId, DroneId, Tick})'. It is
%% uniform enough for a detection roll, it is a pure function of things both
%% islands already agree on, and `phash2/1' is specified to be portable across
%% releases and platforms — unlike `phash/2', and unlike `term_to_binary/1' on a
%% map, which is what made two identical islands disagree about their own engine
%% fingerprint (REGISTER I.12).
%%
%% The consequence worth stating: a given drone at a given tick is either seen
%% or not seen, and it is the SAME answer on both machines and on every replay.
-module(sensor).

-behaviour(dronex_sensor_model).

-include("airspace.hrl").

-export([observe/3, place/1, ghosts/2, contact/6]).

-export_type([sensor/0, contact/0]).

%% ⚠ NOT A TARGET. A sensor has no health, no owner in the fight, and no way to
%% be attacked. It is terrain.
-type sensor() :: #{id := term(), x := integer(), y := integer(), z := integer()}.

%% What a sensor says it saw: where, how sure, and which sensor said it. There is
%% deliberately NO drone id — a non-cooperative sensor does not learn who it is
%% looking at, which is exactly what makes track association a real problem
%% rather than string concatenation on a self-reported identity.
-type contact() :: #{sensor := term(), tick := non_neg_integer(),
                     x := integer(), y := integer(), z := integer(),
                     confidence := 0..1000}.

%%==============================================================================
%% Where the network stands
%%==============================================================================

%% @doc Fixed placement for phase 1: a ring inside the arena, plus one at the
%% centre.
%%
%% ⚠ FIXED, AND THAT IS THE PHASE. Placement evolves at phase 3 and that is what
%% will finally make two islands visibly different places. A ring is chosen over
%% a grid because it leaves a genuine hole overhead and genuine gaps between
%% adjacent sensors, and holes are the entire point: the counterplay to a network
%% is the approach path, not suppression.
-spec place(pos_integer()) -> [sensor()].
place(N) when N > 0 ->
    %% ⚠ ASKED OF `airspace', NEVER RE-DECLARED. The arena's size belongs to the
    %% module that owns the physics; a second copy here would be a constant in
    %% two places on one release cadence, which is CHARTER.md rule 2's failure in
    %% miniature.
    #{arena_x := Ax, arena_y := Ay} = airspace:limits(),
    Cx = Ax div 2,
    Cy = Ay div 2,
    R = Ax div 4,
    [#{id => centre, x => Cx, y => Cy, z => 0}
     | [ring(K, N, Cx, Cy, R) || K <- lists:seq(1, N - 1)]].

ring(K, N, Cx, Cy, R) ->
    A = fixed:wrap((K * 256) div (N - 1)),
    #{id => {ring, K},
      x => Cx + R * fixed:cos(A) div 32768,
      y => Cy + R * fixed:sin(A) div 32768,
      z => 0}.

%%==============================================================================
%% What it sees
%%==============================================================================

%% @doc Ground truth in, a contact or a miss out.
-spec observe(map(), map(), map()) -> {ok, contact()} | miss.
observe(#{x := X, y := Y, z := Z, id := DroneId}, #{id := _} = Sensor, Env) ->
    Tick = maps:get(tick, Env, 0),
    ranged(reach(Sensor, X, Y, Z), Sensor, DroneId, Tick, X, Y, Z);
observe(_Truth, _Sensor, _Env) ->
    miss.

reach(#{x := Sx, y := Sy, z := Sz}, X, Y, Z) -> fixed:mag3(X - Sx, Y - Sy, Z - Sz).

%% Out of range is a miss with no roll at all: a sensor that could see beyond its
%% range with low probability would have no edge, and an edge is what a corridor
%% is made of.
ranged(D, _Sensor, _DroneId, _Tick, _X, _Y, _Z) when D > ?SENSOR_RANGE ->
    miss;
ranged(D, #{id := SensorId}, DroneId, Tick, X, Y, Z) ->
    rolled(draw(detect, SensorId, DroneId, Tick) < chance(D), D, SensorId, DroneId, Tick, X, Y, Z).

rolled(false, _D, _SensorId, _DroneId, _Tick, _X, _Y, _Z) ->
    miss;
rolled(true, D, SensorId, DroneId, Tick, X, Y, Z) ->
    {ok, contact(SensorId, Tick,
                 X + wobble(D, SensorId, DroneId, Tick, 1),
                 Y + wobble(D, SensorId, DroneId, Tick, 2),
                 Z + wobble(D, SensorId, DroneId, Tick, 3),
                 confidence(D))}.

%% @doc A contact, in the field set the counter-UAS line settled on: which sensor,
%% when, where, how sure. `observed_at' is the TICK and never a wall clock.
-spec contact(term(), non_neg_integer(), integer(), integer(), integer(), 0..1000) ->
    contact().
contact(SensorId, Tick, X, Y, Z, Confidence) ->
    #{sensor => SensorId, tick => Tick, x => X, y => Y, z => Z,
      confidence => Confidence}.

%% Detection probability in per-mille, falling linearly from `p_near' at the
%% sensor to `p_far' at the edge of its range.
chance(D) ->
    ?SENSOR_P_NEAR - ((?SENSOR_P_NEAR - ?SENSOR_P_FAR) * D) div ?SENSOR_RANGE.

%% Confidence is the same curve. A far contact is both less likely to happen and
%% worth less when it does, which is what stops the fringe of a network being as
%% good as its middle.
confidence(D) -> chance(D).

%% Position error, growing linearly with range and signed by the hash. A near
%% contact is nearly exact; one at the fringe is out by tens of metres, so a
%% single contact is not a firing solution and a track has to be built.
wobble(D, SensorId, DroneId, Tick, Axis) ->
    Span = (?SENSOR_NOISE * D) div ?SENSOR_RANGE,
    spread(draw({noise, Axis}, SensorId, DroneId, Tick), Span).

spread(_Draw, 0) -> 0;
spread(Draw, Span) -> (Draw rem (2 * Span + 1)) - Span.

%%==============================================================================
%% ⚠ GHOSTS, WHICH ARE WHAT MAKE THE THRESHOLD WORTH HAVING
%%==============================================================================

%% @doc What a sensor reports that is not there.
%%
%% Without false alarms, any confirmation threshold above one is strictly worse
%% than one: more evidence would only ever mean later, never safer. The whole
%% counter-UAS tradeoff — cue at ghosts and waste battery, or see too late —
%% exists because a network sometimes sees nothing at all.
-spec ghosts([sensor()], non_neg_integer()) -> [contact()].
ghosts(Sensors, Tick) ->
    [ghost(S, Tick) || #{id := Id} = S <- Sensors,
                       draw(ghost, Id, ghost, Tick) < ?SENSOR_GHOSTS].

%% Somewhere inside the sensor's range, at a plausible altitude. A ghost that
%% appeared outside the range it can see would be a tell, and a network whose
%% false alarms are distinguishable from its detections is not modelling the
%% problem.
ghost(#{id := Id, x := Sx, y := Sy}, Tick) ->
    #{arena_z := Az} = airspace:limits(),
    A = fixed:wrap(draw(ghost_bearing, Id, ghost, Tick) rem 256),
    D = draw(ghost_range, Id, ghost, Tick) rem ?SENSOR_RANGE,
    contact(Id, Tick,
            Sx + D * fixed:cos(A) div 32768,
            Sy + D * fixed:sin(A) div 32768,
            draw(ghost_alt, Id, ghost, Tick) rem Az,
            confidence(D)).

%%==============================================================================
%% The draw
%%==============================================================================

%% Per-mille, from a hash of everything that identifies this roll. Pure, stable
%% across nodes and releases, and the same on every replay.
draw(Salt, SensorId, DroneId, Tick) ->
    erlang:phash2({Salt, SensorId, DroneId, Tick}, 1000).
