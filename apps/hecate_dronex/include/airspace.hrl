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
    launch = 0 :: integer()
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
