%%% @doc The airspace, as records. EVERY FIELD IS AN INTEGER.
%%%
%%% There is no float anywhere in the match path, by design: a published raid
%%% must replay byte for byte on a machine that did not host it, and libm
%%% transcendentals are not bit-identical across libc versions. `fixed' carries
%%% the unit scheme and the sine table.
%%%
%%% Units, from `fixed':
%%%   position       1 metre   = 20480 units
%%%   velocity       1 m/s     = 1024 units per TICK
%%%   acceleration   1 m/s^2   = 51.2 units per tick squared
%%%   angle          full turn = 256
%%%   battery        1 joule   = 100 units (centijoules)
%%%   health         full      = 10000

%% One drone in flight.
%%
%% ⚠ `yaw' IS WHERE THE SENSOR CONE AND THE WEAPON POINT, and it is the only
%% attitude there is. Roll and pitch are not modelled: design/DESIGN_THE_AIRSPACE
%% assumes the airframe's inner loop, because a controller made to learn attitude
%% stabilisation before anything else spends its whole budget not crashing, and
%% the tactics this repository exists to find never appear. Insight 059 is what
%% that looks like from outside.
-record(drone, {
    id :: term(),
    side :: attacker | defender,
    x = 0 :: integer(),
    y = 0 :: integer(),
    z = 0 :: integer(),
    vx = 0 :: integer(),
    vy = 0 :: integer(),
    vz = 0 :: integer(),
    yaw = 0 :: 0..255,
    %% The yaw rate ACTUALLY APPLIED last tick, after clamping, which is what a
    %% gyro reads. Not the commanded value: a controller that asked for more than
    %% the airframe can do should feel the airframe's answer.
    yaw_rate = 0 :: integer(),
    battery = 0 :: integer(),
    health = 0 :: integer(),
    release_heat = 0 :: non_neg_integer(),
    launch_heat = 0 :: non_neg_integer(),
    %% Guided interceptors remaining. Finite, which is what makes committing one
    %% at range a gamble rather than a free action.
    magazine = 0 :: non_neg_integer(),
    dead = false :: boolean(),
    %% ⚠ WITHDRAWN IS NOT DEAD AND THE DIFFERENCE IS THE WHOLE POINT OF IT.
    %% A withdrawn drone left the engagement alive and its genome goes back on
    %% the roster; a dead one does not. Without somewhere to go, the only
    %% alternative to fighting is dying, which is the squeeze insight 062 closed
    %% programme P7 on: no COSTLESS restraint lever exists, so restraint is
    %% inseparable from starvation. This is that lever.
    withdrawn = false :: boolean(),
    %% ⚠ HOW LONG IT HAS BEEN LOITERING AT THE EDGE, AND IT EXISTS BECAUSE A
    %% SPEED GATE ALONE COULD BE REACHED BY CRASHING. Clamping a wall impact sets
    %% the speed to zero, so on the very next tick a drone that had just flown
    %% into the boundary at 17 m/s was slow, at the edge, and eligible to leave.
    %% Withdrawal is sustained slow flight in the margin instead, which cannot be
    %% arrived at by accident and costs two seconds of predictable flying.
    withdraw_hold = 0 :: non_neg_integer(),
    %% ⚠ WHAT IT SAID LAST TICK, AND THE DELAY IS THE POINT. A controller reads
    %% this from OTHER drones, so what it hears is always one tick old. Zero
    %% latency would not be communication, it would be a shared brain: a signal
    %% has to be about the PAST for acting on it to be a problem worth solving,
    %% and it is what makes memory in the controller load-bearing.
    signal = [0, 0, 0, 0] :: [integer()],
    %% Proprioception of being hurt, reset every tick. It CONFLATES being hit,
    %% striking a wall, hitting the ground and colliding with another drone, and
    %% that conflation is deliberate: a real airframe cannot cleanly tell them
    %% apart either, and separating them here would hand the controller
    %% information the export target will not have.
    damage_taken = 0 :: integer()
}).

%% One released munition in flight.
%%
%% ⚠ IT IS NOT A HITSCAN. It travels, it expires, and it can miss, so a drone
%% that fires is committing to a prediction. Leading a manoeuvring target is
%% exactly the kind of thing a recurrent controller can learn and a feedforward
%% one cannot, which is one of the reasons the brain has memory.
-record(munition, {
    owner :: term(),
    side :: attacker | defender,
    %% An unguided release flies straight and is a knife-fight weapon: at 50 m/s^2
    %% of evasion an unguided shot is unhittable beyond about 15 m. A guided
    %% interceptor steers, which is what makes range worth anything.
    guided = false :: boolean(),
    target = undefined :: term(),
    x = 0 :: integer(),
    y = 0 :: integer(),
    z = 0 :: integer(),
    vx = 0 :: integer(),
    vy = 0 :: integer(),
    vz = 0 :: integer(),
    ttl = 0 :: non_neg_integer()
}).

%% What a controller commands. Clamped by the engine rather than trusted, which
%% is the same contract a real flight controller offers.
%%
%% Thrust is in the BODY frame because that is what an airframe takes. A
%% world-frame velocity command would be an autopilot the export target does not
%% have.
-record(intent, {
    thrust_fwd = 0 :: integer(),
    thrust_lat = 0 :: integer(),
    thrust_vert = 0 :: integer(),
    yaw_rate = 0 :: integer(),
    %% ⚠ TWO WEAPONS, DIFFERENT IN KIND RATHER THAN IN SIZE, and the earlier
    %% one-weapon rule is withdrawn on arithmetic rather than on taste. At 60 m/s
    %% a shot needs 1.7 s to cross 100 m, and a target with 50 m/s^2 of
    %% acceleration displaces about 70 m in that time against a 2 m hit radius.
    %% The unguided release is therefore effective inside roughly 15 m and
    %% nowhere else, which would have made every engagement a knife fight and
    %% left "learned to shoot at range" unreachable rather than unlearned.
    release = 0 :: integer(),
    launch = 0 :: integer(),
    %% ⚠ FOUR INTEGERS WHOSE MEANING NOTHING DECLARES. A channel that carried
    %% something named, "my position" or "target bearing", would be a hand-coded
    %% tactic with evolution reduced to tuning its gain, and it would foreclose
    %% the only interesting outcome. What a signal means is decoded afterwards by
    %% correlating it against everything else in the frame, and if it correlates
    %% with nothing then nothing was being said.
    signal = [0, 0, 0, 0] :: [integer()]
}).

%% The whole world at one tick. Everything needed to produce the next one.
-record(arena, {
    tick = 0 :: non_neg_integer(),
    drones = [] :: list(),
    munitions = [] :: list(),
    %% Carried and not yet drawn from. Sensor noise at item 3 and the static
    %% defence at item 8 both need it, and threading a seed through afterwards
    %% means finding every site that reached for the process-global generator,
    %% where the ones that were missed look fine.
    seed = 0 :: integer()
}).

%% ==========================================================================
%% THE STATIC DEFENCE, ITEM 8 PHASE 1
%% ==========================================================================
%%
%% ⚠ TERRAIN, NOT TARGETS. A sensor cannot be destroyed. Destructible sensors
%% would give an attacker a second objective, and multiple objectives is a
%% balance problem this repository has no means to settle — the same reasoning
%% that gives a drone exactly one weapon. The counterplay to a network is the
%% APPROACH PATH: fly low, fly around, fly through the gap.
%%
%% ⚠⚠ AND THESE ARE PHYSICS, SO THEY SHIP WITH THE IMAGE. They are in
%% `airspace:limits/0' and therefore inside the engine fingerprint, which means
%% two islands running different sensor constants refuse each other rather than
%% fighting a match neither can interpret.

%% ⚠ HOW MANY STATIONS AN ISLAND FIELDS, AND IT IS THE DIAL THE VIABILITY SWEEP
%% TURNS. Five: one at the centre and four on a ring, which leaves a genuine hole
%% overhead and genuine gaps between neighbours. More would close the corridors
%% and make attacking hopeless, which is the failure the design names as most
%% likely — so this number is set on the measurement, with the whole sweep
%% published including the settings that made raiding pointless.
-ifndef(SENSORS).
-define(SENSORS, 5).
-endif.

%% 350 m. Shorter than the 400 m two swarms start apart, so an attacker is not
%% detected at spawn and the approach is a decision rather than a formality.
-ifndef(SENSOR_RANGE).
-define(SENSOR_RANGE, 7168000).
-endif.

%% Detection probability in per-mille, at the sensor and at the edge of its
%% range. Falling off is what makes a corridor a corridor: at the fringe it sees
%% you four times in ten, which is not nothing and is not a wall.
-ifndef(SENSOR_P_NEAR).
-define(SENSOR_P_NEAR, 950).
-endif.
-ifndef(SENSOR_P_FAR).
-define(SENSOR_P_FAR, 400).
-endif.

%% Position error at maximum range, scaling linearly to nothing at the sensor.
%% 40 m: enough that a raw contact is not a firing solution and a track has to
%% be built from several.
-ifndef(SENSOR_NOISE).
-define(SENSOR_NOISE, 819200).
-endif.

%% ⚠ FALSE ALARMS ARE WHAT MAKE THE THRESHOLD A TRADEOFF. Without ghosts, any
%% threshold above one is strictly worse than one and the interesting number
%% stops being interesting. Per-mille chance per sensor per tick.
-ifndef(SENSOR_GHOSTS).
-define(SENSOR_GHOSTS, 12).
-endif.

%% ⚠⚠ THE INTERESTING NUMBER. Contacts needed before a track is CONFIRMED and
%% the network says anything out loud. Too sensitive and it cues its drones at
%% ghosts, which spends battery flying at nothing; too conservative and it sees
%% the attacker too late to launch. Fixed in phase 1, evolved in phase 2.
-ifndef(CONFIRM_EVIDENCE).
-define(CONFIRM_EVIDENCE, 3).
-endif.

%% How near a contact must fall to a track's predicted position to be counted as
%% the same object. 60 m, comfortably above the sensor noise so a real track
%% keeps accumulating, comfortably below the spacing of a spread swarm.
-ifndef(TRACK_GATE).
-define(TRACK_GATE, 1228800).
-endif.

%% Ticks without an update before a track is dropped. Two seconds at 20 Hz: long
%% enough to ride out a missed detection, short enough that the network stops
%% shouting about something that has gone.
-ifndef(TRACK_DROP_TICKS).
-define(TRACK_DROP_TICKS, 40).
-endif.
