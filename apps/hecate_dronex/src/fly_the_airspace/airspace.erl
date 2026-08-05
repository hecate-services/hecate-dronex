%% @doc The world a drone flies in. PURE, INTEGER, AND THE SAME ON EVERY MACHINE.
%%
%% THIS EXISTS SO A FIGHT HOSTED BY THE ISLAND THAT WAS ATTACKED CAN BE CHECKED
%% BY THE ISLAND THAT ATTACKED IT. `step/2' is a function of the arena and the
%% intents and of nothing else: no wall clock, no process dictionary, no
%% unseeded generator, no `math:' call. `airspace_determinism_tests' asserts the
%% last one over the compiled call graph rather than trusting this paragraph.
%%
%% ==========================================================================
%% THE CONSTANTS, AND WHERE THEY CAME FROM
%% ==========================================================================
%%
%% CHARTER.md rule 7: real quantities in real units, because a controller
%% evolved against invented physics cannot leave the simulator, and leaving is
%% the point. Every number below is a racing quadcopter's number, and the ones
%% that are choices rather than measurements say so.
%%
%%   arena            1000 x 1000 x 300 m
%%   thrust           50 m/s^2 peak, about 6:1 thrust to weight
%%   gravity          9.8046875 m/s^2, exactly, because the unit is 1/51.2
%%   terminal speed   about 35 m/s under full thrust against drag
%%   battery          79.2 kJ, about 22 Wh, a 4S pack
%%   hover draw       about 150 W, so roughly 9 minutes of hovering
%%   full-thrust draw about 1.7 kW, so roughly 46 seconds
%%   engagement cap   60 seconds
%%
%% ⚠ THE LAST THREE ARE THE POINT OF THE BATTERY. Hovering is nearly free
%% against a 60 second engagement and flying hard is not, so energy is a thing to
%% spend tactically rather than a countdown everybody experiences identically. A
%% drone that flies at full thrust throughout runs dry before the cap.
%%
%% ⚠⚠ POWER GOES AS THRUST TO THE THREE HALVES, which is momentum theory for a
%% rotor in hover and is computed as `T * isqrt(T)' rather than approximated.
%% The alternative considered was linear, and it was rejected on the arithmetic:
%% at a 5:1 thrust ratio, linear draw makes full throttle only five times hover,
%% so the battery never binds inside an engagement and the whole mechanism is
%% decoration.
-module(airspace).

-include("airspace.hrl").

-export([new/1, new/2, step/2, finished/1, winner/1]).
-export([drones/1, munitions/1, tick_of/1, seed_of/1, drone/2, alive/1, alive/2]).
-export([limits/0, max_ticks/0]).

%%==============================================================================
%% The world
%%==============================================================================

%% 1000 m by 1000 m by 300 m. Bounded because an unbounded volume lets a losing
%% swarm simply leave, which is neither a fight nor a result.
-define(ARENA_X, 20480000).
-define(ARENA_Y, 20480000).
-define(ARENA_Z, 6144000).

-define(MAX_TICKS, 1200).

%%==============================================================================
%% Flight
%%==============================================================================

%% 9.8046875 m/s^2. Exact in this model rather than 9.81 rounded: the
%% acceleration unit is 1/51.2 and 502 is what lands on it.
-define(GRAVITY, 502).
%% 50 m/s^2, about 6:1 thrust to weight, which is a racing airframe.
-define(MAX_ACCEL, 2560).
%% Quadratic drag: `a = v * |v| div DRAG_DIV'. Chosen so that full thrust against
%% drag settles at about 35 m/s, rather than by imposing a speed cap, which would
%% be a wall the controller can feel and physics cannot explain.
-define(DRAG_DIV, 501760).
%% 12 angle units per tick, about 337 degrees per second.
-define(MAX_YAW_RATE, 12).

%%==============================================================================
%% Energy
%%==============================================================================

-define(START_BATTERY, 7920000).
%% draw = T * isqrt(T) div 15. See the module doc.
-define(DRAW_DIV, 15).

%%==============================================================================
%% Damage
%%==============================================================================

-define(START_HEALTH, 10000).
%% Four hits kill.
-define(HIT_DAMAGE, 2500).
%% 2 m. A munition passing within this of a drone hits it.
-define(HIT_RADIUS, 40960).
%% 0.5 m each, so two drones touch at 1 m.
-define(DRONE_RADIUS, 10240).
%% An impact at 40 m/s is fatal, and slower ones scale linearly. Used for walls,
%% for the ground and for drone-on-drone collisions, because they are the same
%% event.
-define(KILL_SPEED, 40960).

%%==============================================================================
%% The weapon
%%==============================================================================

%% 60 m/s. It travels, it expires and it can miss, so firing is committing to a
%% prediction.
-define(MUNITION_SPEED, 61440).
%% 5 seconds, so about 300 m of reach.
-define(MUNITION_TTL, 100).
%% 200 J a shot. The cooldown is what limits the rate; this is what makes a drone
%% that fires wildly land sooner.
-define(MUNITION_COST, 20000).
-define(RELEASE_COOL, 20).
-define(RELEASE_THRESHOLD, 1).

%%==============================================================================
%% Building one
%%==============================================================================

%% @doc An arena from a list of `{Id, Side, X, Y, Z, Yaw}'.
-spec new([tuple()]) -> #arena{}.
new(Placed) -> new(Placed, 0).

-spec new([tuple()], integer()) -> #arena{}.
new(Placed, Seed) ->
    #arena{tick = 0, seed = Seed, munitions = [],
           drones = [placed(P) || P <- Placed]}.

placed({Id, Side, X, Y, Z, Yaw}) ->
    #drone{id = Id, side = Side,
           x = X, y = Y, z = Z,
           yaw = fixed:wrap(Yaw),
           battery = ?START_BATTERY,
           health = ?START_HEALTH}.

%%==============================================================================
%% One tick
%%==============================================================================

%% @doc Advance the world by one tick, given what each drone commanded.
%%
%% ⚠ THE ORDER OF THE STAGES IS PART OF THE PHYSICS AND IS NOT AN IMPLEMENTATION
%% DETAIL. Two of them are load-bearing and would be easy to swap by accident:
%%
%%   munitions move and are tested for hits BEFORE new ones are released, so a
%%   munition cannot strike anything on the tick it was created. Releasing first
%%   would make a point-blank shot instantaneous and unavoidable, which is a
%%   hitscan weapon wearing a projectile's clothes.
%%
%%   damage is accumulated across every stage and applied ONCE at the end, so a
%%   drone that is hit, rammed and driven into a wall on the same tick takes all
%%   three. Applying each as it happens would let the first one kill it and the
%%   other two land on a corpse, which makes the outcome depend on the order the
%%   list happened to be in.
-spec step(#arena{}, #{term() => #intent{}}) -> #arena{}.
step(#arena{tick = T, drones = Ds, munitions = Ms} = A, Intents) ->
    Flown = [fly(D, intent_for(D, Intents)) || D <- Ds],
    Moved = [bounded(D) || D <- Flown],
    {Live, Struck} = strike(Ms, Moved),
    Collided = collide(Struck),
    Released = [release(D, intent_for(D, Intents)) || D <- Collided],
    A#arena{tick = T + 1,
            drones = [settle(D) || {D, _M} <- Released],
            munitions = aged(Live) ++ [M || {_D, M} <- Released, M =/= none]}.

intent_for(#drone{id = Id}, Intents) -> maps:get(Id, Intents, #intent{}).

%%==============================================================================
%% Flight
%%==============================================================================

%% A dead drone is inert. It keeps its last position so a frame still draws it,
%% and it stops being a participant.
fly(#drone{dead = true} = D, _I) -> D;
fly(#drone{} = D, #intent{} = I) -> thrusting(D, thrust(D, I), yawed(D, I)).

%% Yaw first, so thrust is applied in the heading the drone commanded this tick
%% rather than the one it had last tick. Either is defensible; this one is
%% chosen because it makes a commanded turn take effect immediately, which is
%% what a controller with a one-tick view expects.
yawed(#drone{yaw = Y}, #intent{yaw_rate = R}) ->
    fixed:wrap(Y + fixed:clamp(R, -?MAX_YAW_RATE, ?MAX_YAW_RATE)).

%% ⚠ AN EMPTY BATTERY PRODUCES NO THRUST, AND THE DRONE IS NOT REMOVED. It
%% becomes a falling object that can still be hit and can still hit the ground.
%% Running out is a way to lose rather than a way to leave.
thrust(#drone{battery = B}, _I) when B =< 0 -> {0, 0, 0};
thrust(#drone{yaw = Yaw}, #intent{thrust_fwd = F, thrust_lat = L, thrust_vert = V}) ->
    {Cf, Cl, Cv} = fixed:scale_to(F, L, V, ?MAX_ACCEL),
    world_frame(Cf, Cl, Cv, Yaw).

%% Body frame to world frame. A drone commands thrust along its own nose,
%% because that is what an airframe takes; a world-frame command would be an
%% autopilot the export target does not have.
world_frame(F, L, V, Yaw) ->
    Sin = fixed:sin(Yaw),
    Cos = fixed:cos(Yaw),
    {(F * Cos - L * Sin) div 32768, (F * Sin + L * Cos) div 32768, V}.

thrusting(#drone{} = D, {Ax, Ay, Az}, Yaw) ->
    Drawn = drained(D, fixed:mag3(Ax, Ay, Az)),
    Drawn#drone{yaw = Yaw,
                vx = velocity(D#drone.vx, Ax),
                vy = velocity(D#drone.vy, Ay),
                vz = velocity(D#drone.vz, Az - ?GRAVITY)}.

%% Drag opposes motion and grows with the square of speed, so there is a terminal
%% velocity rather than a cap. `abs' keeps the sign right without a case.
velocity(V, A) -> V + A - (V * abs(V)) div ?DRAG_DIV.

drained(#drone{battery = B} = D, Mag) -> D#drone{battery = max(0, B - draw(Mag))}.

%% Momentum theory: induced power goes as thrust to the three halves. `isqrt' is
%% the only reason this is expressible in integers at all.
draw(0) -> 0;
draw(Mag) -> Mag * fixed:isqrt(Mag) div ?DRAW_DIV.

%%==============================================================================
%% Position, walls and the ground
%%==============================================================================

%% ⚠ CLAMPED AND HURT, NEVER BOUNCED AND NEVER TELEPORTED. A boundary is a hazard
%% rather than a resource: a drone that flies into one loses the speed it was
%% carrying and takes the damage that speed was worth. Bouncing would make the
%% wall a free reversal, and wrapping would make the arena a torus, which is a
%% different world.
bounded(#drone{dead = true} = D) -> D;
bounded(#drone{x = X, y = Y, z = Z, vx = Vx, vy = Vy, vz = Vz} = D) ->
    {Nx, Sx} = stopped(X + Vx, Vx, ?ARENA_X),
    {Ny, Sy} = stopped(Y + Vy, Vy, ?ARENA_Y),
    {Nz, Sz} = stopped(Z + Vz, Vz, ?ARENA_Z),
    Hurt = hurt(D, impact_damage(fixed:mag3(Sx, Sy, Sz))),
    Hurt#drone{x = Nx, y = Ny, z = Nz,
               vx = kept(Vx, Sx), vy = kept(Vy, Sy), vz = kept(Vz, Sz)}.

%% Returns the clamped coordinate and the speed that was absorbed by the surface.
stopped(P, V, _Max) when P < 0 -> {0, abs(V)};
stopped(P, V, Max) when P > Max -> {Max, abs(V)};
stopped(P, _V, _Max) -> {P, 0}.

%% A surface that absorbed anything takes all of that axis's velocity with it.
kept(_V, Absorbed) when Absorbed > 0 -> 0;
kept(V, _Absorbed) -> V.

%% Linear in impact speed, fatal at 40 m/s. The same rule serves walls, the
%% ground and drone-on-drone collisions, because at this level of detail they are
%% the same event and three separate curves would be three numbers to justify.
impact_damage(0) -> 0;
impact_damage(Speed) -> ?START_HEALTH * Speed div ?KILL_SPEED.

hurt(#drone{health = H, damage_taken = T} = D, Damage) ->
    D#drone{health = H - Damage, damage_taken = T + Damage}.

%%==============================================================================
%% Munitions
%%==============================================================================

%% Move every munition, test what it passed through on the way, and report the
%% survivors alongside the drones it hurt.
strike(Ms, Ds) -> lists:foldl(fun fly_one/2, {[], Ds}, Ms).

fly_one(#munition{x = X, y = Y, z = Z, vx = Vx, vy = Vy, vz = Vz} = M, {Kept, Ds}) ->
    Moved = M#munition{x = X + Vx, y = Y + Vy, z = Z + Vz},
    resolved(Moved, {X, Y, Z}, Ds, Kept).

resolved(M, From, Ds, Kept) -> landed(hit(M, From, Ds), M, Ds, Kept).

%% A munition that hits is spent. One that misses carries on.
landed(none, M, Ds, Kept) -> {[M | Kept], Ds};
landed(Id, _M, Ds, Kept) -> {Kept, [maybe_hurt(D, Id) || D <- Ds]}.

maybe_hurt(#drone{id = Id} = D, Id) -> hurt(D, ?HIT_DAMAGE);
maybe_hurt(D, _Id) -> D.

%% ⚠ THE TEST IS AGAINST THE SEGMENT THE MUNITION TRAVELLED, NOT ITS END POINT.
%% At 60 m/s a munition covers 3 m in a tick and the hit radius is 2 m, so a
%% point test would let it pass clean through a drone it struck squarely. That is
%% tunnelling, it happens more often the faster the shot, and it would read as a
%% weapon that mysteriously fails at close range.
hit(M, From, Ds) -> nearest([D || D <- Ds, not D#drone.dead, hostile(M, D)], M, From).

hostile(#munition{side = S}, #drone{side = S}) -> false;
hostile(_M, _D) -> true.

nearest([], _M, _From) -> none;
nearest([#drone{} = D | Rest], M, From) -> closer(within(D, M, From), D, Rest, M, From).

closer(true, #drone{id = Id}, _Rest, _M, _From) -> Id;
closer(false, _D, Rest, M, From) -> nearest(Rest, M, From).

within(#drone{x = Px, y = Py, z = Pz}, #munition{x = Bx, y = By, z = Bz}, {Ax, Ay, Az}) ->
    segment_distance_squared({Ax, Ay, Az}, {Bx, By, Bz}, {Px, Py, Pz})
        =< ?HIT_RADIUS * ?HIT_RADIUS.

%% Squared distance from point P to the segment AB, in integers.
segment_distance_squared({Ax, Ay, Az}, {Bx, By, Bz}, {Px, Py, Pz}) ->
    {Dx, Dy, Dz} = {Bx - Ax, By - Ay, Bz - Az},
    {Wx, Wy, Wz} = {Px - Ax, Py - Ay, Pz - Az},
    Den = Dx * Dx + Dy * Dy + Dz * Dz,
    Num = Wx * Dx + Wy * Dy + Wz * Dz,
    at_closest({Wx, Wy, Wz}, {Dx, Dy, Dz}, clamped_t(Num, Den), Den).

%% A zero-length segment is a point, which is the standing-still case rather than
%% an error.
clamped_t(_Num, 0) -> 0;
clamped_t(Num, _Den) when Num < 0 -> 0;
clamped_t(Num, Den) when Num > Den -> Den;
clamped_t(Num, _Den) -> Num.

at_closest({Wx, Wy, Wz}, _D, 0, _Den) -> Wx * Wx + Wy * Wy + Wz * Wz;
at_closest({Wx, Wy, Wz}, {Dx, Dy, Dz}, T, Den) ->
    Cx = Wx - Dx * T div Den,
    Cy = Wy - Dy * T div Den,
    Cz = Wz - Dz * T div Den,
    Cx * Cx + Cy * Cy + Cz * Cz.

aged(Ms) -> [M#munition{ttl = N - 1} || #munition{ttl = N} = M <- Ms, N > 1].

%%==============================================================================
%% Releasing
%%==============================================================================

%% Returns the drone and either a new munition or `none'.
release(#drone{dead = true} = D, _I) -> {D, none};
release(#drone{release_heat = H} = D, _I) when H > 0 ->
    {D#drone{release_heat = H - 1}, none};
release(#drone{} = D, #intent{release = R}) when R < ?RELEASE_THRESHOLD -> {D, none};
release(#drone{battery = B} = D, _I) when B < ?MUNITION_COST -> {D, none};
release(#drone{} = D, _I) -> fired(D).

%% ⚠ THE MUNITION INHERITS THE DRONE'S OWN VELOCITY, WHICH IS HOW A DRONE AIMS
%% VERTICALLY AT ALL. There is no pitch here, so yaw alone would leave every shot
%% horizontal and nothing could ever be engaged at a different altitude. Adding
%% the launcher's velocity is what a real launch does, and it makes climbing or
%% diving into the shot a TACTIC rather than a channel somebody had to invent.
fired(#drone{x = X, y = Y, z = Z, yaw = Yaw, side = S, id = Id,
             vx = Vx, vy = Vy, vz = Vz, battery = B} = D) ->
    M = #munition{owner = Id, side = S, x = X, y = Y, z = Z,
                  vx = Vx + ?MUNITION_SPEED * fixed:cos(Yaw) div 32768,
                  vy = Vy + ?MUNITION_SPEED * fixed:sin(Yaw) div 32768,
                  vz = Vz,
                  ttl = ?MUNITION_TTL},
    {D#drone{battery = B - ?MUNITION_COST, release_heat = ?RELEASE_COOL}, M}.

%%==============================================================================
%% Collisions
%%==============================================================================

%% ⚠ COLLISIONS IGNORE SIDES, AND MUNITIONS DO NOT. Two solid objects in one
%% volume hit each other whoever owns them, so flying in tight formation costs
%% something. Munitions are the other way round: there is no friendly fire, which
%% is a simplification and a dial rather than a physical claim. With it on,
%% avoiding your own swarm becomes most of the problem a controller has to solve,
%% and that is a second objective in disguise.
collide(Ds) -> [rammed(D, Ds) || D <- Ds].

rammed(#drone{dead = true} = D, _Ds) -> D;
rammed(#drone{} = D, Ds) ->
    hurt(D, lists:sum([impact_damage(closing(D, O)) || O <- Ds, touching(D, O)])).

touching(#drone{id = Id}, #drone{id = Id}) -> false;
touching(_D, #drone{dead = true}) -> false;
touching(#drone{x = Ax, y = Ay, z = Az}, #drone{x = Bx, y = By, z = Bz}) ->
    Dx = Ax - Bx, Dy = Ay - By, Dz = Az - Bz,
    Dx * Dx + Dy * Dy + Dz * Dz =< (2 * ?DRONE_RADIUS) * (2 * ?DRONE_RADIUS).

closing(#drone{vx = Ax, vy = Ay, vz = Az}, #drone{vx = Bx, vy = By, vz = Bz}) ->
    fixed:mag3(Ax - Bx, Ay - By, Az - Bz).

%%==============================================================================
%% Settling
%%==============================================================================

%% Damage is applied once, here, after every stage that could cause any. See the
%% note on `step/2'.
settle(#drone{dead = true} = D) -> D;
settle(#drone{health = H} = D) when H =< 0 -> D#drone{dead = true, health = 0};
settle(#drone{} = D) -> D.

%%==============================================================================
%% Ending
%%==============================================================================

%% @doc Whether this engagement is over.
%%
%% A side with nobody left has lost. Reaching the cap is a draw, and it is a real
%% outcome rather than a failure: two swarms that decline to engage produce
%% exactly that, and calling it a fault would hide the behaviour.
-spec finished(#arena{}) -> boolean().
finished(#arena{tick = T}) when T >= ?MAX_TICKS -> true;
finished(#arena{} = A) -> alive(A, attacker) =:= 0 orelse alive(A, defender) =:= 0.

%% @doc Who won, or `draw'.
-spec winner(#arena{}) -> attacker | defender | draw | undecided.
winner(#arena{} = A) -> decided(finished(A), alive(A, attacker), alive(A, defender)).

decided(false, _Att, _Def) -> undecided;
decided(true, 0, 0) -> draw;
decided(true, 0, _Def) -> defender;
decided(true, _Att, 0) -> attacker;
decided(true, _Att, _Def) -> draw.

%%==============================================================================
%% Reading one
%%==============================================================================

-spec drones(#arena{}) -> [#drone{}].
drones(#arena{drones = Ds}) -> Ds.

-spec munitions(#arena{}) -> [#munition{}].
munitions(#arena{munitions = Ms}) -> Ms.

-spec tick_of(#arena{}) -> non_neg_integer().
tick_of(#arena{tick = T}) -> T.

-spec seed_of(#arena{}) -> integer().
seed_of(#arena{seed = S}) -> S.

-spec drone(#arena{}, term()) -> #drone{} | undefined.
drone(#arena{drones = Ds}, Id) -> found([D || #drone{id = I} = D <- Ds, I =:= Id]).

found([D | _]) -> D;
found([]) -> undefined.

-spec alive(#arena{}) -> non_neg_integer().
alive(#arena{drones = Ds}) -> length([D || D <- Ds, not D#drone.dead]).

-spec alive(#arena{}, attacker | defender) -> non_neg_integer().
alive(#arena{drones = Ds}, Side) ->
    length([D || #drone{side = S, dead = false} = D <- Ds, S =:= Side]).

-spec max_ticks() -> pos_integer().
max_ticks() -> ?MAX_TICKS.

%% @doc Every constant, so a test and a published fact can read them from the one
%% place they are defined rather than restating them.
%%
%% ⚠ THE ENGAGEMENT'S RULES TRAVEL WITH ITS RESULT. Two islands running different
%% constants produce results comparable to nothing, and a sibling shipped exactly
%% that: the site pinned one engine commit and the service pinned another, with a
%% turn-count self-check the only thing between it and drawing a fight nobody
%% fought.
-spec limits() -> map().
limits() ->
    #{arena_x => ?ARENA_X, arena_y => ?ARENA_Y, arena_z => ?ARENA_Z,
      gravity => ?GRAVITY, max_accel => ?MAX_ACCEL, drag_div => ?DRAG_DIV,
      max_yaw_rate => ?MAX_YAW_RATE,
      start_battery => ?START_BATTERY, draw_div => ?DRAW_DIV,
      start_health => ?START_HEALTH, hit_damage => ?HIT_DAMAGE,
      hit_radius => ?HIT_RADIUS, drone_radius => ?DRONE_RADIUS,
      kill_speed => ?KILL_SPEED,
      munition_speed => ?MUNITION_SPEED, munition_ttl => ?MUNITION_TTL,
      munition_cost => ?MUNITION_COST, release_cool => ?RELEASE_COOL,
      max_ticks => ?MAX_TICKS}.
