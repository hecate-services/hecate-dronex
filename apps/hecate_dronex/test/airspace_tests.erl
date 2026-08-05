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
