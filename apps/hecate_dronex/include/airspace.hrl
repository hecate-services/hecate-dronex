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
    dead = false :: boolean(),
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
    %% Above the threshold, release. One weapon, because two is a balance problem
    %% this repository has no means to settle.
    release = 0 :: integer()
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
