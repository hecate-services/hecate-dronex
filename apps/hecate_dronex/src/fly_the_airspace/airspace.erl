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
-export([present/2, survivors/1, lock/2]).
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
%% Leaving
%%==============================================================================

%% ⚠ 5 m/s, AND THE SPEED LIMIT IS WHAT MAKES WITHDRAWAL A DECISION. A drone that
%% reaches a LATERAL boundary slowly is extracted alive; one that arrives fast is
%% clamped and hurt exactly as before. So the arena's edge is escape and hazard at
%% once, depending entirely on how you approach it, and leaving costs a long slow
%% predictable run rather than a keystroke.
%%
%% ⚠⚠ THERE IS NO `withdraw' ACTUATOR AND THERE WILL NOT BE ONE. CHARTER.md rule
%% 8: no channel may name a tactic. Retreat is flying somewhere at a speed, which
%% the existing controls already express.
-define(WITHDRAW_SPEED, 5120).
%% 10 m of a lateral wall, held for 2 seconds. See `withdraw_hold' in the header
%% for why a single slow tick is not enough.
-define(WITHDRAW_MARGIN, 204800).
-define(WITHDRAW_TICKS, 40).

%%==============================================================================
%% The weapons
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

%% THE GUIDED INTERCEPTOR. Faster, longer-legged, finite and expensive.
%%
%% ⚠ ITS TURN RADIUS IS DELIBERATELY WORSE THAN A DRONE'S, WHICH IS WHAT KEEPS
%% EVASION REAL. At 80 m/s pulling 150 m/s^2 it turns in about 43 m; a drone at
%% 35 m/s pulling 50 m/s^2 turns in about 25 m. So a target that sees it coming
%% and turns hard at close range can beat it, and a target engaged at range
%% cannot. That is the whole reason for having two weapons rather than one good
%% one: the release rewards closing, the interceptor rewards seeing first.
-define(INTERCEPTOR_SPEED, 81920).
-define(INTERCEPTOR_TURN, 7680).
-define(INTERCEPTOR_TTL, 150).
-define(INTERCEPTOR_COST, 100000).
-define(INTERCEPTOR_DAMAGE, 5000).
-define(LAUNCH_COOL, 40).
-define(MAGAZINE, 4).
%% 600 m, and a 45 degree half-angle seeker. `cos(32)' is cos(45) on the binary
%% scale, so the cone test is a dot product and never an inverse trig call.
-define(LOCK_RANGE, 12288000).
-define(SEEKER_COS, 23170).

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
           magazine = ?MAGAZINE,
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
    Armed = [fire(D, intent_for(D, Intents), Collided) || D <- Collided],
    A#arena{tick = T + 1,
            drones = [settle(Flown2) || {Flown2, _Fired} <- Armed],
            munitions = aged(Live) ++ lists:append([Fired || {_Flown2, Fired} <- Armed])}.

intent_for(#drone{id = Id}, Intents) -> maps:get(Id, Intents, #intent{}).

%%==============================================================================
%% Flight
%%==============================================================================

%% A dead drone is inert. It keeps its last position so a frame still draws it,
%% and it stops being a participant.
%% @doc A drone that is dead or withdrawn is out of the engagement: it does not
%% fly, does not collide, cannot be hit and cannot shoot. Two states, one
%% predicate, because every stage needs the same answer and asking `dead' alone
%% would leave a withdrawn drone still fighting.
out(#drone{dead = true}) -> true;
out(#drone{withdrawn = true}) -> true;
out(#drone{}) -> false.

fly(#drone{} = D, _I) when D#drone.dead; D#drone.withdrawn -> D;
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
bounded(#drone{} = D) when D#drone.dead; D#drone.withdrawn -> D;
bounded(#drone{} = D) -> edged(clamped(D)).

%% ⚠ THE CLAMP HAPPENS FIRST AND THE EXIT IS CHECKED AFTER, so hitting a wall is
%% never a way through one. A drone leaves by loitering slowly in the margin for
%% two seconds, which is a controlled egress rather than an impact, and which is
%% expensive precisely because it is slow and predictable while somebody may be
%% shooting.
edged(#drone{} = D) ->
    holding(D, in_margin(D), fixed:mag3(D#drone.vx, D#drone.vy, D#drone.vz)).

%% Only the four LATERAL walls are a way out. The ground and the ceiling are
%% surfaces: landing gently in somebody else's airspace is not withdrawing from
%% it, and neither is bumping the ceiling.
in_margin(#drone{x = X, y = Y}) ->
    X =< ?WITHDRAW_MARGIN orelse X >= ?ARENA_X - ?WITHDRAW_MARGIN
        orelse Y =< ?WITHDRAW_MARGIN orelse Y >= ?ARENA_Y - ?WITHDRAW_MARGIN.

holding(#drone{} = D, true, Speed) when Speed =< ?WITHDRAW_SPEED -> counted(D);
holding(#drone{} = D, _InMargin, _Speed) -> D#drone{withdraw_hold = 0}.

counted(#drone{withdraw_hold = N} = D) when N + 1 >= ?WITHDRAW_TICKS ->
    D#drone{withdrawn = true, vx = 0, vy = 0, vz = 0};
counted(#drone{withdraw_hold = N} = D) -> D#drone{withdraw_hold = N + 1}.

clamped(#drone{x = X, y = Y, z = Z, vx = Vx, vy = Vy, vz = Vz} = D) ->
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

fly_one(#munition{} = M0, {Kept, Ds}) ->
    #munition{x = X, y = Y, z = Z, vx = Vx, vy = Vy, vz = Vz} = M = steer(M0, Ds),
    Moved = M#munition{x = X + Vx, y = Y + Vy, z = Z + Vz},
    resolved(Moved, {X, Y, Z}, Ds, Kept).

%% ⚠ PURE PURSUIT AT CONSTANT SPEED WITH A LATERAL ACCELERATION LIMIT, which is
%% what a cheap seeker actually does and is beatable in exactly the way a real
%% one is. The interceptor turns toward where the target IS, not where it will
%% be, so a target that turns harder than 150 m/s^2 worth of radius at its own
%% speed can walk around the outside of it.
%%
%% A LOST TARGET GOES BALLISTIC RATHER THAN VANISHING. If the drone it was
%% chasing dies or withdraws mid-flight, the interceptor keeps its velocity and
%% flies on until it expires, which is both what a real one does and the only
%% honest thing: a munition that disappeared when its target left would let a
%% swarm clear the sky by withdrawing one drone.
steer(#munition{guided = false} = M, _Ds) -> M;
steer(#munition{target = Id} = M, Ds) -> homing(M, seek(Id, Ds)).

seek(Id, Ds) -> found([D || #drone{id = I} = D <- Ds, I =:= Id]).

homing(#munition{} = M, undefined) -> M;
homing(#munition{} = M, #drone{} = T) when T#drone.dead; T#drone.withdrawn -> M;
homing(#munition{x = X, y = Y, z = Z, vx = Vx, vy = Vy, vz = Vz} = M,
       #drone{x = Tx, y = Ty, z = Tz}) ->
    {Wx, Wy, Wz} = fixed:at_length(Tx - X, Ty - Y, Tz - Z, ?INTERCEPTOR_SPEED),
    {Ax, Ay, Az} = fixed:scale_to(Wx - Vx, Wy - Vy, Wz - Vz, ?INTERCEPTOR_TURN),
    {Nx, Ny, Nz} = fixed:at_length(Vx + Ax, Vy + Ay, Vz + Az, ?INTERCEPTOR_SPEED),
    M#munition{vx = Nx, vy = Ny, vz = Nz}.

resolved(M, From, Ds, Kept) -> landed(hit(M, From, Ds), M, Ds, Kept).

%% A munition that hits is spent. One that misses carries on.
landed(none, M, Ds, Kept) -> {[M | Kept], Ds};
landed(Id, M, Ds, Kept) -> {Kept, [maybe_hurt(D, Id, damage_of(M)) || D <- Ds]}.

%% The interceptor is finite and expensive, so it hits for twice the release:
%% two of them kill, and a full magazine is exactly enough for two drones.
damage_of(#munition{guided = true}) -> ?INTERCEPTOR_DAMAGE;
damage_of(#munition{guided = false}) -> ?HIT_DAMAGE.

maybe_hurt(#drone{id = Id} = D, Id, Damage) -> hurt(D, Damage);
maybe_hurt(D, _Id, _Damage) -> D.

%% ⚠ THE TEST IS AGAINST THE SEGMENT THE MUNITION TRAVELLED, NOT ITS END POINT.
%% At 60 m/s a munition covers 3 m in a tick and the hit radius is 2 m, so a
%% point test would let it pass clean through a drone it struck squarely. That is
%% tunnelling, it happens more often the faster the shot, and it would read as a
%% weapon that mysteriously fails at close range.
hit(M, From, Ds) -> nearest([D || D <- Ds, not out(D), hostile(M, D)], M, From).

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

%% @doc Returns the drone and every munition it produced this tick.
%%
%% Both weapons are offered on the same tick and both may go, because they are
%% different in kind rather than in size and a drone that has closed to knife
%% range while holding a lock has earned both.
fire(#drone{} = D, #intent{} = I, Ds) -> launched(released(D, I), I, Ds).

released(#drone{} = D, _I) when D#drone.dead; D#drone.withdrawn -> {D, []};
released(#drone{release_heat = H} = D, _I) when H > 0 -> {D#drone{release_heat = H - 1}, []};
released(#drone{} = D, #intent{release = R}) when R < ?RELEASE_THRESHOLD -> {D, []};
released(#drone{battery = B} = D, _I) when B < ?MUNITION_COST -> {D, []};
released(#drone{} = D, _I) -> shot(D).

%% ⚠ THE MUNITION INHERITS THE DRONE'S OWN VELOCITY, WHICH IS HOW A DRONE AIMS
%% VERTICALLY AT ALL. There is no pitch here, so yaw alone would leave every shot
%% horizontal and nothing could ever be engaged at a different altitude. Adding
%% the launcher's velocity is what a real launch does, and it makes climbing or
%% diving into the shot a TACTIC rather than a channel somebody had to invent.
shot(#drone{x = X, y = Y, z = Z, yaw = Yaw, side = S, id = Id,
            vx = Vx, vy = Vy, vz = Vz, battery = B} = D) ->
    M = #munition{owner = Id, side = S, guided = false, x = X, y = Y, z = Z,
                  vx = Vx + ?MUNITION_SPEED * fixed:cos(Yaw) div 32768,
                  vy = Vy + ?MUNITION_SPEED * fixed:sin(Yaw) div 32768,
                  vz = Vz,
                  ttl = ?MUNITION_TTL},
    {D#drone{battery = B - ?MUNITION_COST, release_heat = ?RELEASE_COOL}, [M]}.

launched({#drone{} = D, Ms}, _I, _Ds) when D#drone.dead; D#drone.withdrawn -> {D, Ms};
launched({#drone{launch_heat = H} = D, Ms}, _I, _Ds) when H > 0 ->
    {D#drone{launch_heat = H - 1}, Ms};
launched({#drone{} = D, Ms}, #intent{launch = L}, _Ds) when L < ?RELEASE_THRESHOLD ->
    {D, Ms};
launched({#drone{magazine = 0} = D, Ms}, _I, _Ds) -> {D, Ms};
launched({#drone{battery = B} = D, Ms}, _I, _Ds) when B < ?INTERCEPTOR_COST -> {D, Ms};
launched({#drone{} = D, Ms}, _I, Ds) -> committed(D, Ms, lock(D, Ds)).

%% ⚠ NO LOCK, NO LAUNCH, AND NOTHING IS SPENT. A launch without a target would be
%% a wasted interceptor a controller could not tell apart from a fired one, so
%% pointing at something is a real precondition rather than a suggestion. The
%% controller is told nothing extra to make this decidable: bearing, range and
%% affiliation are already in its contact channels, so `am I locked' is something
%% it has to learn rather than something it is handed.
committed(#drone{} = D, Ms, undefined) -> {D, Ms};
committed(#drone{magazine = N, battery = B} = D, Ms, TargetId) ->
    {D#drone{magazine = N - 1, battery = B - ?INTERCEPTOR_COST,
             launch_heat = ?LAUNCH_COOL},
     [interceptor(D, TargetId) | Ms]}.

interceptor(#drone{x = X, y = Y, z = Z, yaw = Yaw, side = S, id = Id,
                   vx = Vx, vy = Vy, vz = Vz}, TargetId) ->
    #munition{owner = Id, side = S, guided = true, target = TargetId,
              x = X, y = Y, z = Z,
              vx = Vx + ?INTERCEPTOR_SPEED * fixed:cos(Yaw) div 32768,
              vy = Vy + ?INTERCEPTOR_SPEED * fixed:sin(Yaw) div 32768,
              vz = Vz,
              ttl = ?INTERCEPTOR_TTL}.

%% @doc The nearest hostile inside the seeker cone and inside lock range, or
%% `undefined'.
%%
%% The cone is tested by DOT PRODUCT against the nose, never by an angle, so
%% there is no `atan2' on the match path. `fixed:along/5' says how far a
%% direction points along a heading as a fraction of its length, and 23170 is
%% cos(45 degrees) on the 32768 scale.
-spec lock(#drone{}, [#drone{}]) -> term() | undefined.
lock(#drone{} = D, Ds) ->
    closest([{range(D, O), O} || O <- Ds, not out(O), enemy(D, O), in_cone(D, O)]).

enemy(#drone{side = S}, #drone{side = S}) -> false;
enemy(_D, _O) -> true.

range(#drone{x = X, y = Y, z = Z}, #drone{x = Ox, y = Oy, z = Oz}) ->
    fixed:mag3(Ox - X, Oy - Y, Oz - Z).

in_cone(#drone{} = D, #drone{} = O) -> seen(D, O, range(D, O)).

seen(_D, _O, R) when R > ?LOCK_RANGE -> false;
seen(_D, _O, 0) -> false;
seen(#drone{x = X, y = Y, z = Z, yaw = Yaw}, #drone{x = Ox, y = Oy, z = Oz}, R) ->
    fixed:along(Ox - X, Oy - Y, Oz - Z, R, Yaw) >= ?SEEKER_COS.

closest([]) -> undefined;
closest(Cands) -> id_of(hd(lists:keysort(1, Cands))).

id_of({_Range, #drone{id = Id}}) -> Id.

%% Collisions
%%==============================================================================

%% ⚠ COLLISIONS IGNORE SIDES, AND MUNITIONS DO NOT. Two solid objects in one
%% volume hit each other whoever owns them, so flying in tight formation costs
%% something. Munitions are the other way round: there is no friendly fire, which
%% is a simplification and a dial rather than a physical claim. With it on,
%% avoiding your own swarm becomes most of the problem a controller has to solve,
%% and that is a second objective in disguise.
collide(Ds) -> [rammed(D, Ds) || D <- Ds].

rammed(#drone{} = D, _Ds) when D#drone.dead; D#drone.withdrawn -> D;
rammed(#drone{} = D, Ds) ->
    hurt(D, lists:sum([impact_damage(closing(D, O)) || O <- Ds, touching(D, O)])).

touching(#drone{id = Id}, #drone{id = Id}) -> false;
touching(_D, #drone{dead = true}) -> false;
touching(_D, #drone{withdrawn = true}) -> false;
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
settle(#drone{withdrawn = true} = D) -> D;
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
finished(#arena{} = A) -> present(A, attacker) =:= 0 orelse present(A, defender) =:= 0.

%% @doc Who won, or `draw'.
-spec winner(#arena{}) -> attacker | defender | draw | undecided.
%% ⚠ ON PRESENCE, NOT ON SURVIVAL, AND THE TWO ARE NOW DIFFERENT QUESTIONS. Who
%% held the airspace and which genomes came home are separate facts: a side can
%% withdraw intact and lose the engagement, which is exactly the trade withdrawal
%% exists to offer. `survivors/1' answers the other one.
winner(#arena{} = A) -> decided(finished(A), present(A, attacker), present(A, defender)).

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

%% @doc How many of a side are still IN the engagement: alive and not withdrawn.
-spec present(#arena{}, attacker | defender) -> non_neg_integer().
present(#arena{drones = Ds}, Side) ->
    length([D || #drone{side = S} = D <- Ds, S =:= Side, not out(D)]).

%% @doc Every drone that came home, whether it withdrew or fought to the end.
%%
%% This is the list the roster is rebuilt from, and it is why withdrawal is worth
%% anything: CHARTER.md spends a genome when it flies and returns the survivors,
%% so leaving alive is the difference between a lineage that continues and one
%% that does not.
-spec survivors(#arena{}) -> [#drone{}].
survivors(#arena{drones = Ds}) -> [D || #drone{dead = false} = D <- Ds].

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
      interceptor_speed => ?INTERCEPTOR_SPEED, interceptor_turn => ?INTERCEPTOR_TURN,
      interceptor_ttl => ?INTERCEPTOR_TTL, interceptor_cost => ?INTERCEPTOR_COST,
      interceptor_damage => ?INTERCEPTOR_DAMAGE, launch_cool => ?LAUNCH_COOL,
      magazine => ?MAGAZINE, lock_range => ?LOCK_RANGE, seeker_cos => ?SEEKER_COS,
      withdraw_speed => ?WITHDRAW_SPEED, withdraw_margin => ?WITHDRAW_MARGIN,
      withdraw_ticks => ?WITHDRAW_TICKS,
      max_ticks => ?MAX_TICKS}.
