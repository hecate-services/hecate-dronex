%% @doc The flight model, checked against numbers derived outside it.
%%
%% ⚠ EVERY EXPECTED VALUE HERE IS COMPUTED FROM THE PHYSICS RATHER THAN READ OFF
%% A RUN. A test that asserts what the code already does agrees with itself and
%% catches nothing: a sibling's first engine test asserted `turns > 0` against a
%% number the same code produced, and an off-by-one passed cleanly, because the
%% wrong fight is still a fight.
-module(airspace_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).
-define(MS, 1024).

%%==============================================================================
%% Falling and hovering
%%==============================================================================

one(Opts) ->
    airspace:new([{a, attacker,
                   maps:get(x, Opts, 500 * ?M),
                   maps:get(y, Opts, 500 * ?M),
                   maps:get(z, Opts, 200 * ?M),
                   maps:get(yaw, Opts, 0)}]).

run(A, _I, 0) -> A;
run(A, I, N) -> run(airspace:step(A, I), I, N - 1).

idle() -> #{a => #intent{}}.

d(A) -> airspace:drone(A, a).

%% Commanding nothing means falling, because gravity is not optional and there is
%% no ground effect, no autopilot and no hold.
a_drone_that_commands_nothing_falls_test() ->
    After = run(one(#{}), idle(), 10),
    #drone{z = Z, vz = Vz} = d(After),
    ?assert(Vz < 0),
    ?assert(Z < 200 * ?M).

%% ⚠ HOVER IS EXACT, AND THAT IS A PROPERTY OF THE UNIT SCHEME RATHER THAN LUCK.
%% Commanding vertical thrust equal to gravity gives a net acceleration of
%% exactly zero, so a drone that starts at rest stays at the altitude it started
%% at, tick after tick, with no drift in either direction.
hovering_holds_altitude_exactly_test() ->
    #{gravity := G} = airspace:limits(),
    I = #{a => #intent{thrust_vert = G}},
    After = run(one(#{}), I, 200),
    #drone{z = Z, vz = Vz} = d(After),
    ?assertEqual(200 * ?M, Z),
    ?assertEqual(0, Vz).

%%==============================================================================
%% The battery
%%==============================================================================

%% Derived, not observed: draw = T * isqrt(T) div 15 at T = gravity, against a
%% 7,920,000 cJ pack, is about 9 minutes. The assertion is on the MINUTES,
%% because that is the quantity the design argues about.
hover_endurance_is_about_nine_minutes_test() ->
    #{gravity := G, start_battery := B, draw_div := Div} = airspace:limits(),
    Draw = G * fixed:isqrt(G) div Div,
    Seconds = (B div Draw) div fixed:ticks_per_second(),
    ?assert(Seconds > 500),
    ?assert(Seconds < 580).

%% ⚠ AND FULL THRUST IS SHORTER THAN AN ENGAGEMENT, WHICH IS THE WHOLE POINT OF
%% THE BATTERY. A drone that flies at the limit throughout runs dry before the
%% cap, so energy is a thing to spend tactically. If this ever stopped being
%% true, the battery would be decoration and nothing else in the suite would
%% notice.
full_thrust_endurance_is_shorter_than_an_engagement_test() ->
    #{max_accel := T, start_battery := B, draw_div := Div} = airspace:limits(),
    Draw = T * fixed:isqrt(T) div Div,
    Ticks = B div Draw,
    ?assert(Ticks < airspace:max_ticks()),
    ?assert(Ticks > airspace:max_ticks() div 2).

%% Superlinear: doubling thrust costs more than twice as much. Momentum theory,
%% and the reason a linear draw was rejected.
power_grows_faster_than_thrust_test() ->
    #{start_battery := B, draw_div := Div} = airspace:limits(),
    Draw = fun (T) -> T * fixed:isqrt(T) div Div end,
    ?assert(Draw(2000) > 2 * Draw(1000)),
    ?assert(B > 0).

the_battery_drains_while_thrusting_test() ->
    #{gravity := G, start_battery := B} = airspace:limits(),
    After = run(one(#{}), #{a => #intent{thrust_vert = G}}, 50),
    ?assert((d(After))#drone.battery < B).

%% ⚠ AN EMPTY BATTERY IS A WAY TO LOSE, NOT A WAY TO LEAVE. The drone is not
%% removed and not frozen: it produces no thrust and falls, and it can still be
%% hit and can still hit the ground.
an_empty_battery_produces_no_thrust_test() ->
    #{gravity := G} = airspace:limits(),
    A0 = one(#{}),
    Flat = A0#arena{drones = [(hd(airspace:drones(A0)))#drone{battery = 0}]},
    After = run(Flat, #{a => #intent{thrust_vert = G}}, 5),
    #drone{vz = Vz, dead = Dead} = d(After),
    ?assert(Vz < 0),
    ?assertNot(Dead).

%%==============================================================================
%% Drag
%%==============================================================================

%% ⚠ TERMINAL VELOCITY IS DERIVED FROM THE DRAG CONSTANT AND NEVER READ OFF A
%% RUN. At equilibrium thrust equals drag, so v = sqrt(max_accel * drag_div).
%% There is no speed cap anywhere in the engine: a cap would be a wall the
%% controller can feel and the physics cannot explain.
%%
%% ⚠ AND IT SETTLES ON THE PREDICTION EXACTLY, WHICH IS STRONGER THAN "CLOSE TO".
%% At v = 35840 the drag term is 2560 to the unit, so the net acceleration is
%% zero and the speed sticks there. An approximate assertion would pass against a
%% drag constant that was wrong by a few percent.
%%
%% ⚠⚠ 250 TICKS, NOT 400, AND THE REASON IS A RESULT RATHER THAN A FUDGE. At
%% 35 m/s from the middle of a 1000 m arena the drone reaches the far wall at
%% about tick 286, grinds itself against it at full throttle, and is dead by 300.
%% That is correct physics and it is what the first version of this test was
%% actually measuring.
terminal_speed_matches_the_drag_equation_test() ->
    #{max_accel := T, drag_div := Div} = airspace:limits(),
    Predicted = fixed:isqrt(T * Div),
    ?assertEqual(35 * ?MS, Predicted),
    After = run(one(#{z => 300 * ?M}), #{a => #intent{thrust_fwd = T}}, 250),
    #drone{vx = Vx, dead = Dead} = d(After),
    ?assertNot(Dead),
    ?assertEqual(Predicted, Vx).

%% The other half of the same finding: a boundary is a hazard that keeps hurting
%% while you keep pushing into it. Full throttle into a wall is fatal, which is
%% what makes the arena's edge a thing to respect rather than a place to park.
flying_into_a_wall_at_full_throttle_kills_test() ->
    #{max_accel := T} = airspace:limits(),
    After = run(one(#{z => 300 * ?M}), #{a => #intent{thrust_fwd = T}}, 400),
    ?assert((d(After))#drone.dead).

%%==============================================================================
%% Thrust
%%==============================================================================

%% ⚠ THE FREE DIAGONAL, TESTED WHERE IT WOULD APPEAR. Commanding the limit on
%% all three axes must not give root three times the thrust. Measured as applied
%% acceleration: after one tick from rest, the velocity plus the gravity that was
%% subtracted from it IS the thrust that was applied.
thrust_is_limited_as_a_vector_and_not_per_axis_test() ->
    #{max_accel := T, gravity := G} = airspace:limits(),
    I = #{a => #intent{thrust_fwd = T, thrust_lat = T, thrust_vert = T}},
    After = run(one(#{}), I, 1),
    #drone{vx = Vx, vy = Vy, vz = Vz} = d(After),
    ?assert(fixed:mag3(Vx, Vy, Vz + G) =< T).

thrust_follows_the_nose_test() ->
    #{max_accel := T} = airspace:limits(),
    East = run(one(#{yaw => 0}), #{a => #intent{thrust_fwd = T}}, 1),
    North = run(one(#{yaw => 64}), #{a => #intent{thrust_fwd = T}}, 1),
    ?assert((d(East))#drone.vx > 0),
    ?assertEqual(0, (d(East))#drone.vy),
    ?assert((d(North))#drone.vy > 0),
    ?assertEqual(0, (d(North))#drone.vx).

yaw_rate_is_clamped_test() ->
    #{max_yaw_rate := R} = airspace:limits(),
    After = run(one(#{yaw => 0}), #{a => #intent{yaw_rate = 1000}}, 1),
    ?assertEqual(R, (d(After))#drone.yaw).

yaw_wraps_rather_than_saturating_test() ->
    #{max_yaw_rate := R} = airspace:limits(),
    After = run(one(#{yaw => 0}), #{a => #intent{yaw_rate = R}}, 30),
    ?assertEqual(fixed:wrap(30 * R), (d(After))#drone.yaw).

%%==============================================================================
%% Walls and the ground
%%==============================================================================

%% ⚠ CLAMPED AND HURT, NEVER BOUNCED AND NEVER WRAPPED. A bounce would make the
%% wall a free reversal; wrapping would make the arena a torus, which is a
%% different world with different tactics.
a_wall_stops_a_drone_and_hurts_it_test() ->
    #{max_accel := T, arena_x := Max, start_health := H} = airspace:limits(),
    After = run(one(#{x => 990 * ?M}), #{a => #intent{thrust_fwd = T}}, 60),
    #drone{x = X, vx = Vx, health = Health} = d(After),
    ?assertEqual(Max, X),
    ?assertEqual(0, Vx),
    ?assert(Health < H).

the_ground_is_a_surface_like_any_other_test() ->
    After = run(one(#{z => 5 * ?M}), idle(), 60),
    #drone{z = Z, vz = Vz} = d(After),
    ?assertEqual(0, Z),
    ?assertEqual(0, Vz).

%% A fast enough impact is fatal, which is what makes altitude a resource that
%% has to be managed rather than a free axis.
a_fast_impact_kills_test() ->
    #{max_accel := T} = airspace:limits(),
    Down = #{a => #intent{thrust_vert = -T}},
    After = run(one(#{z => 300 * ?M}), Down, 200),
    ?assert((d(After))#drone.dead).

%%==============================================================================
%% Munitions
%%==============================================================================

%% The attacker's nose is on the defender, 20 m away.
pair() ->
    airspace:new([{a, attacker, 500 * ?M, 500 * ?M, 100 * ?M, 0},
                  {b, defender, 520 * ?M, 500 * ?M, 100 * ?M, 128}]).

%% The same two, with the defender well off the firing axis, for the tests that
%% are about the launcher rather than about the hit.
clear_range() ->
    airspace:new([{a, attacker, 10 * ?M, 500 * ?M, 100 * ?M, 0},
                  {b, defender, 10 * ?M, 900 * ?M, 100 * ?M, 0}]).

%% ⚠ A MUNITION CANNOT HIT ON THE TICK IT WAS RELEASED. Releasing before moving
%% would make a point-blank shot instantaneous and unavoidable, which is a
%% hitscan weapon wearing a projectile's clothes. Two drones a metre apart, and
%% the defender survives the tick the attacker fires on.
a_munition_cannot_strike_on_the_tick_it_is_released_test() ->
    #{start_health := H} = airspace:limits(),
    Close = airspace:new([{a, attacker, 500 * ?M, 500 * ?M, 100 * ?M, 0},
                          {b, defender, 501 * ?M, 500 * ?M, 100 * ?M, 0}]),
    After = airspace:step(Close, #{a => #intent{release = 1}}),
    ?assertEqual(H, (airspace:drone(After, b))#drone.health),
    ?assertEqual(1, length(airspace:munitions(After))).

a_release_costs_battery_and_starts_a_cooldown_test() ->
    #{start_battery := B, munition_cost := C, release_cool := Cool} = airspace:limits(),
    After = airspace:step(pair(), #{a => #intent{release = 1}}),
    ?assertEqual(B - C, (airspace:drone(After, a))#drone.battery),
    ?assertEqual(Cool, (airspace:drone(After, a))#drone.release_heat).

%% ⚠ THE TARGET IS OFF THE LINE OF FIRE ON PURPOSE. The first version of this
%% test used `pair/0', whose two drones are 20 m apart along the firing axis, so
%% the munition reached the defender on tick 7 and the assertion failed with zero
%% munitions in flight. The engine was right and the fixture was wrong, and the
%% thing it accidentally proved now has a test of its own below.
the_cooldown_refuses_a_second_release_test() ->
    Held = #{a => #intent{release = 1}},
    After = run(clear_range(), Held, 10),
    ?assertEqual(1, length(airspace:munitions(After))).

%% Two drones 20 m apart with the attacker's nose on the defender. The munition
%% covers 3 m a tick, so it arrives around tick 7 and is spent on arrival.
a_munition_fired_down_the_nose_hits_test() ->
    #{start_health := H, hit_damage := Dmg} = airspace:limits(),
    After = run(pair(), #{a => #intent{release = 1}}, 10),
    ?assertEqual(H - Dmg, (airspace:drone(After, b))#drone.health),
    ?assertEqual([], airspace:munitions(After)).

a_munition_expires_test() ->
    #{munition_ttl := Ttl} = airspace:limits(),
    Fired = airspace:step(clear_range(), #{a => #intent{release = 1}}),
    After = run(Fired, #{}, Ttl + 2),
    ?assertEqual([], airspace:munitions(After)).

four_hits_kill_test() ->
    #{start_health := H, hit_damage := Dmg} = airspace:limits(),
    ?assertEqual(0, H rem Dmg),
    ?assertEqual(4, H div Dmg).

%% ⚠ THE TUNNELLING TEST, AND THE REASON `segment_distance_squared' EXISTS. A
%% munition inherits its launcher's velocity, so a shot from a drone at speed
%% covers more than the 4 m that two hit radii span, and a test against the
%% munition's END POINT would let it pass clean through a drone it struck
%% squarely. Both endpoints here are 3 m from the target and the path goes
%% through the middle of it.
a_munition_cannot_tunnel_through_a_drone_test() ->
    #{start_health := H} = airspace:limits(),
    A0 = pair(),
    Target = airspace:drone(A0, b),
    Fast = A0#arena{munitions = [#munition{owner = a, side = attacker,
                                           x = Target#drone.x - 3 * ?M,
                                           y = Target#drone.y,
                                           z = Target#drone.z,
                                           vx = 6 * ?M, vy = 0, vz = 0,
                                           ttl = 50}]},
    After = airspace:step(Fast, #{}),
    ?assert((airspace:drone(After, b))#drone.health < H),
    ?assertEqual([], airspace:munitions(After)).

%% No friendly fire, which is a simplification and a dial rather than a physical
%% claim: with it on, avoiding your own swarm becomes most of the problem a
%% controller has to solve, and that is a second objective in disguise.
a_munition_passes_through_its_own_side_test() ->
    #{start_health := H} = airspace:limits(),
    A0 = airspace:new([{a, attacker, 500 * ?M, 500 * ?M, 100 * ?M, 0},
                       {b, attacker, 520 * ?M, 500 * ?M, 100 * ?M, 0}]),
    Friendly = A0#arena{munitions = [#munition{owner = a, side = attacker,
                                               x = 519 * ?M, y = 500 * ?M,
                                               z = 100 * ?M,
                                               vx = 2 * ?M, ttl = 50}]},
    After = airspace:step(Friendly, #{}),
    ?assertEqual(H, (airspace:drone(After, b))#drone.health).

%%==============================================================================
%% Collisions
%%==============================================================================

%% ⚠ COLLISIONS IGNORE SIDES WHERE MUNITIONS DO NOT. Two solid objects in one
%% volume hit each other whoever owns them, so flying in tight formation costs
%% something even without friendly fire.
two_drones_in_one_place_hurt_each_other_test() ->
    #{start_health := H, max_accel := T} = airspace:limits(),
    Facing = airspace:new([{a, attacker, 499 * ?M, 500 * ?M, 100 * ?M, 0},
                           {b, attacker, 501 * ?M, 500 * ?M, 100 * ?M, 128}]),
    After = run(Facing, #{a => #intent{thrust_fwd = T},
                          b => #intent{thrust_fwd = T}}, 20),
    ?assert((airspace:drone(After, a))#drone.health < H),
    ?assert((airspace:drone(After, b))#drone.health < H).

drones_that_are_apart_do_not_collide_test() ->
    #{start_health := H, gravity := G} = airspace:limits(),
    Hover = #{a => #intent{thrust_vert = G}, b => #intent{thrust_vert = G}},
    After = run(pair(), Hover, 50),
    ?assertEqual(H, (airspace:drone(After, a))#drone.health),
    ?assertEqual(H, (airspace:drone(After, b))#drone.health).

%%==============================================================================
%% Ending
%%==============================================================================

a_fresh_engagement_is_undecided_test() ->
    ?assertNot(airspace:finished(pair())),
    ?assertEqual(undecided, airspace:winner(pair())).

%% Reaching the cap is a DRAW and a real outcome. Two swarms that decline to
%% engage produce exactly this, and calling it a fault would hide the behaviour.
the_cap_is_a_draw_test() ->
    #{gravity := G} = airspace:limits(),
    Hover = #{a => #intent{thrust_vert = G}, b => #intent{thrust_vert = G}},
    After = run(pair(), Hover, airspace:max_ticks()),
    ?assert(airspace:finished(After)),
    ?assertEqual(draw, airspace:winner(After)).

a_side_with_nobody_left_has_lost_test() ->
    A0 = pair(),
    Dead = A0#arena{drones = [set_dead(D) || D <- airspace:drones(A0)]},
    ?assert(airspace:finished(Dead)),
    ?assertEqual(draw, airspace:winner(Dead)),
    OneSide = A0#arena{drones = [dead_if(D, defender) || D <- airspace:drones(A0)]},
    ?assert(airspace:finished(OneSide)),
    ?assertEqual(attacker, airspace:winner(OneSide)),
    ?assertEqual(1, airspace:alive(OneSide)).

set_dead(D) -> D#drone{dead = true}.

dead_if(#drone{side = S} = D, S) -> set_dead(D);
dead_if(D, _S) -> D.

%%==============================================================================
%% Determinism
%%==============================================================================

%% ⚠ THE PROPERTY THE WHOLE INTEGER SCHEME EXISTS FOR. A raid is published by the
%% island that HOSTED it and has to be checkable by the island that flew into it,
%% so two runs of the same start state and the same intents must be equal as
%% terms, not merely similar.
the_same_start_and_the_same_intents_give_the_same_fight_test() ->
    #{max_accel := T, gravity := G} = airspace:limits(),
    I = #{a => #intent{thrust_fwd = T, thrust_vert = G, yaw_rate = 3, release = 1},
          b => #intent{thrust_lat = T, thrust_vert = G, yaw_rate = -2}},
    ?assertEqual(run(pair(), I, 300), run(pair(), I, 300)).

%% And the engagement is a function of the whole start state: a different start
%% gives a different fight, so the equality above is not trivially true of
%% everything.
a_different_start_gives_a_different_fight_test() ->
    #{max_accel := T} = airspace:limits(),
    I = #{a => #intent{thrust_fwd = T}},
    Other = airspace:new([{a, attacker, 501 * ?M, 500 * ?M, 100 * ?M, 0},
                          {b, defender, 520 * ?M, 500 * ?M, 100 * ?M, 128}]),
    ?assertNotEqual(run(pair(), I, 50), run(Other, I, 50)).

a_missing_intent_is_a_drone_that_commanded_nothing_test() ->
    ?assertEqual(run(pair(), #{}, 30), run(pair(), #{a => #intent{}}, 30)).

%%==============================================================================
%% Withdrawal
%%==============================================================================

%% An attacker already inside the western margin, hovering, and a defender in the
%% middle.
edge() ->
    airspace:new([{a, attacker, 5 * ?M, 500 * ?M, 100 * ?M, 128},
                  {b, defender, 500 * ?M, 500 * ?M, 100 * ?M, 0}]).

%% ⚠ THE LEVER INSIGHT 062 COULD NOT FIND. Reaching a lateral wall slowly is an
%% exit rather than an impact: the drone leaves alive, its genome goes home, and
%% it is no longer in the fight.
a_slow_drone_at_a_lateral_wall_withdraws_test() ->
    #{gravity := G, start_health := H, withdraw_ticks := N} = airspace:limits(),
    Creep = #{a => #intent{thrust_vert = G}},
    After = run(edge(), Creep, N + 2),
    Left = airspace:drone(After, a),
    ?assert(Left#drone.withdrawn),
    ?assertNot(Left#drone.dead),
    ?assertEqual(H, Left#drone.health).

%% ⚠ AND CRASHING INTO THE SAME WALL IS NOT A WAY THROUGH IT. Register D.3: a
%% clamp sets the speed to zero, so a purely instantaneous speed gate let a drone
%% arrive at 17 m/s, be stopped by the wall, and qualify as a slow controlled
%% departure on the very next tick. Holding the margin for two seconds cannot be
%% reached that way, and the drone here is still thrusting into the wall, so its
%% hold keeps resetting.
a_drone_that_crashes_into_the_wall_does_not_get_out_through_it_test() ->
    #{max_accel := T, gravity := G, start_health := H,
      withdraw_ticks := N} = airspace:limits(),
    Charge = #{a => #intent{thrust_fwd = T, thrust_vert = G}},
    After = run(edge(), Charge, N * 3),
    Hit = airspace:drone(After, a),
    ?assertNot(Hit#drone.withdrawn),
    ?assert(Hit#drone.health < H).

%% And the hold is a HOLD: interrupting it resets the clock, so a drone cannot
%% accumulate a departure across a fight it kept leaving and rejoining.
an_interrupted_hold_starts_again_test() ->
    #{gravity := G, max_accel := T, withdraw_ticks := N} = airspace:limits(),
    Hover = #{a => #intent{thrust_vert = G}},
    Dash = #{a => #intent{thrust_fwd = T, thrust_vert = G}},
    Nearly = run(edge(), Hover, N - 5),
    ?assertNot((airspace:drone(Nearly, a))#drone.withdrawn),
    Broken = run(Nearly, Dash, 3),
    ?assertEqual(0, (airspace:drone(Broken, a))#drone.withdraw_hold).

%% The ground is a surface, not a door. Landing gently in somebody else's
%% airspace is not withdrawing from it.
the_ground_is_not_a_way_out_test() ->
    After = run(one(#{z => 1 * ?M}), idle(), 40),
    ?assertNot((d(After))#drone.withdrawn),
    ?assertEqual(0, (d(After))#drone.z).

%% A withdrawn drone is out of the engagement, so a side that has all withdrawn
%% has conceded the airspace even though every one of its genomes came home.
withdrawing_concedes_the_airspace_but_keeps_the_genome_test() ->
    #{gravity := G, withdraw_ticks := N} = airspace:limits(),
    Creep = #{a => #intent{thrust_vert = G}, b => #intent{thrust_vert = G}},
    After = run(edge(), Creep, N + 2),
    ?assert(airspace:finished(After)),
    ?assertEqual(defender, airspace:winner(After)),
    ?assertEqual(0, airspace:present(After, attacker)),
    %% but both genomes are alive and go back on their rosters
    ?assertEqual(2, length(airspace:survivors(After))),
    ?assertEqual(1, airspace:alive(After, attacker)).

%%==============================================================================
%% The guided interceptor
%%==============================================================================

%% ⚠ THE ARITHMETIC THAT MADE A SECOND WEAPON NECESSARY, ASSERTED RATHER THAN
%% ARGUED. An unguided shot needs 1.7 s to cross 100 m; a target pulling 50 m/s^2
%% displaces about 70 m in that time against a 2 m hit radius. This is the
%% comparison that decides which weapon is worth carrying at which range.
an_unguided_shot_cannot_reach_an_evading_target_test() ->
    #{munition_speed := S, max_accel := A, hit_radius := R} = airspace:limits(),
    Ticks = 100 * ?M div S,
    Displacement = A * Ticks * Ticks div 2,
    ?assert(Displacement > 20 * R).

a_launch_needs_a_lock_and_spends_nothing_without_one_test() ->
    #{magazine := N, start_battery := B} = airspace:limits(),
    %% b is behind a, well outside the forward seeker cone.
    Behind = airspace:new([{a, attacker, 500 * ?M, 500 * ?M, 100 * ?M, 0},
                           {b, defender, 400 * ?M, 500 * ?M, 100 * ?M, 0}]),
    After = airspace:step(Behind, #{a => #intent{launch = 1}}),
    ?assertEqual(undefined, airspace:lock(airspace:drone(Behind, a),
                                          airspace:drones(Behind))),
    ?assertEqual(N, (airspace:drone(After, a))#drone.magazine),
    ?assertEqual(B, (airspace:drone(After, a))#drone.battery),
    ?assertEqual([], airspace:munitions(After)).

a_target_ahead_is_locked_test() ->
    ?assertEqual(b, airspace:lock(airspace:drone(pair(), a), airspace:drones(pair()))).

a_launch_spends_a_round_and_starts_its_own_cooldown_test() ->
    #{magazine := N, launch_cool := Cool, interceptor_cost := C,
      start_battery := B} = airspace:limits(),
    After = airspace:step(pair(), #{a => #intent{launch = 1}}),
    Shooter = airspace:drone(After, a),
    ?assertEqual(N - 1, Shooter#drone.magazine),
    ?assertEqual(Cool, Shooter#drone.launch_heat),
    ?assertEqual(B - C, Shooter#drone.battery),
    ?assertEqual(1, length(airspace:munitions(After))).

%% ⚠ THE PROPERTY THE WHOLE SECOND WEAPON EXISTS FOR. The target is 200 m away
%% and running: an unguided shot has no chance at that range, and a guided one
%% closes.
a_guided_interceptor_runs_a_fleeing_target_down_test() ->
    #{max_accel := T, gravity := G, start_health := H} = airspace:limits(),
    Far = airspace:new([{a, attacker, 300 * ?M, 500 * ?M, 100 * ?M, 0},
                        {b, defender, 500 * ?M, 500 * ?M, 100 * ?M, 0}]),
    Chase = #{a => #intent{launch = 1, thrust_vert = G},
              b => #intent{thrust_fwd = T, thrust_vert = G}},
    After = run(Far, Chase, 90),
    ?assert((airspace:drone(After, b))#drone.health < H).

%% And it is beatable, which is what stops it being an auto-kill. The
%% interceptor turns in about 43 m at 80 m/s; a drone turns in about 25 m at
%% 35 m/s, so a hard turn at close quarters walks around the outside of it.
the_interceptor_turns_worse_than_a_drone_test() ->
    #{interceptor_speed := Is, interceptor_turn := It,
      max_accel := Dt, drag_div := Div} = airspace:limits(),
    Ds = fixed:isqrt(Dt * Div),
    ?assert(Is * Is div It > Ds * Ds div Dt).

%% A munition whose target leaves keeps flying rather than vanishing. Otherwise a
%% swarm could clear the sky by withdrawing one drone.
a_lost_target_leaves_the_interceptor_ballistic_test() ->
    A0 = pair(),
    Fired = airspace:step(A0, #{a => #intent{launch = 1}}),
    Gone = Fired#arena{drones = [gone_if(D, b) || D <- airspace:drones(Fired)]},
    After = airspace:step(Gone, #{}),
    ?assertEqual(1, length(airspace:munitions(After))).

gone_if(#drone{id = Id} = D, Id) -> D#drone{withdrawn = true};
gone_if(D, _Id) -> D.

both_weapons_may_go_on_one_tick_test() ->
    After = airspace:step(pair(), #{a => #intent{release = 1, launch = 1}}),
    ?assertEqual(2, length(airspace:munitions(After))),
    ?assertEqual(1, length([M || M <- airspace:munitions(After), M#munition.guided])).

%% An empty magazine refuses, spends nothing and starts no cooldown, exactly as a
%% missing lock does. Set directly rather than fired dry over hundreds of ticks,
%% because a long run would also be measuring whether the target survived.
an_empty_magazine_refuses_test() ->
    #{start_battery := B} = airspace:limits(),
    A0 = pair(),
    Dry = A0#arena{drones = [empty_if(D, a) || D <- airspace:drones(A0)]},
    After = airspace:step(Dry, #{a => #intent{launch = 1}}),
    ?assertEqual(0, (airspace:drone(After, a))#drone.magazine),
    ?assertEqual(B, (airspace:drone(After, a))#drone.battery),
    ?assertEqual([], airspace:munitions(After)).

empty_if(#drone{id = Id} = D, Id) -> D#drone{magazine = 0};
empty_if(D, _Id) -> D.

%% ⚠ THE SEEKER HAS A RANGE AND IT IS SHORTER THAN THE ARENA. Two drones at
%% opposite ends are 800 m apart against a 600 m lock, so nothing happens. This
%% is the fixture error that made the first magazine test fail, kept as a test
%% because the range is a rule of the game rather than a detail.
a_target_beyond_lock_range_is_not_locked_test() ->
    #{lock_range := R} = airspace:limits(),
    Far = airspace:new([{a, attacker, 100 * ?M, 500 * ?M, 100 * ?M, 0},
                        {b, defender, 900 * ?M, 500 * ?M, 100 * ?M, 0}]),
    ?assert(800 * ?M > R),
    ?assertEqual(undefined, airspace:lock(airspace:drone(Far, a),
                                          airspace:drones(Far))).
