%% @doc The integer arithmetic, checked against arithmetic done another way.
-module(fixed_tests).

-include_lib("eunit/include/eunit.hrl").

%%==============================================================================
%% Units
%%==============================================================================

%% ⚠ THE ONE RELATION THE WHOLE SCHEME EXISTS FOR. Velocity is units per TICK, so
%% integration is `Pos + Vel' with no division. If this stopped being exact,
%% every position integration would truncate slightly toward zero and the world
%% would acquire a drag nobody wrote.
one_metre_per_second_is_a_whole_number_of_units_per_tick_test() ->
    ?assertEqual(fixed:per_metre(), fixed:per_ms() * fixed:ticks_per_second()).

a_tick_is_fifty_milliseconds_test() ->
    ?assertEqual(20, fixed:ticks_per_second()).

%% The acceleration unit is 1/51.2 m/s^2, stated in tenths because it is not a
%% whole number and rounding it in the accessor would hide that.
the_acceleration_unit_is_stated_in_tenths_test() ->
    ?assertEqual(512, fixed:per_accel()),
    %% 20 m/s^2 is exactly 1024, which is why the thrust ceiling lands on a whole
    %% number at all.
    ?assertEqual(1024, 20 * fixed:per_accel() div 10).

%%==============================================================================
%% Angles
%%==============================================================================

a_full_turn_is_256_test() ->
    ?assertEqual(0, fixed:wrap(256)),
    ?assertEqual(1, fixed:wrap(257)),
    ?assertEqual(255, fixed:wrap(-1)),
    ?assertEqual(0, fixed:wrap(-256)),
    ?assertEqual(128, fixed:wrap(-128)).

%% ⚠ A QUARTER TURN IS 32768 AND NOT 32767, WHICH IS THE WHOLE SCALE RATHER THAN
%% ONE BELOW IT, AND IT MATTERS. `world_frame' divides by 32768, so thrust along
%% the nose at yaw 0 comes out as EXACTLY the commanded value with no rounding
%% at all. One less would lose a unit on every axis-aligned command, for ever,
%% and it would look like a tiny unexplained inefficiency in flying straight.
the_cardinal_angles_are_exact_test() ->
    ?assertEqual(0, fixed:sin(0)),
    ?assertEqual(32768, fixed:sin(64)),
    ?assertEqual(0, fixed:sin(128)),
    ?assertEqual(-32768, fixed:sin(192)),
    ?assertEqual(32768, fixed:cos(0)),
    ?assertEqual(0, fixed:cos(64)),
    %% The identity that makes it free: X * cos(0) div 32768 =:= X.
    ?assertEqual(2560, 2560 * fixed:cos(0) div 32768).

%% Checked against libm HERE, in a test, which is exactly where a float call
%% belongs: the table was generated from it once and the match path never touches
%% it. One unit of 32768 is about 0.003%.
the_table_agrees_with_libm_test() ->
    Off = [abs(fixed:sin(A) - round(math:sin(2 * math:pi() * A / 256) * 32768))
           || A <- lists:seq(0, 255)],
    ?assertEqual(0, lists:max(Off)).

%% sin^2 + cos^2 = 1, to within the rounding of a 32768-scaled table.
the_identity_holds_at_every_angle_test() ->
    Err = [abs(fixed:sin(A) * fixed:sin(A) + fixed:cos(A) * fixed:cos(A)
               - 32768 * 32768) || A <- lists:seq(0, 255)],
    ?assert(lists:max(Err) < 32768 * 4).

%%==============================================================================
%% Arithmetic
%%==============================================================================

isqrt_is_the_floor_of_the_root_test() ->
    [?assertEqual(trunc(math:sqrt(N)), fixed:isqrt(N))
     || N <- [0, 1, 2, 3, 4, 8, 15, 16, 17, 99, 100, 101, 10000, 123456789]].

%% ⚠ THE PROPERTY, NOT A TABLE OF EXAMPLES: r^2 =< N < (r+1)^2. Newton's method
%% is easy to get subtly wrong one either side of a perfect square, and a
%% one-unit error in a distance is a hit that should have been a miss.
isqrt_brackets_every_input_test() ->
    Ns = lists:seq(0, 2000) ++ [N * N || N <- lists:seq(1, 400)]
         ++ [N * N - 1 || N <- lists:seq(2, 400)]
         ++ [N * N + 1 || N <- lists:seq(1, 400)],
    [begin
         R = fixed:isqrt(N),
         ?assert(R * R =< N),
         ?assert((R + 1) * (R + 1) > N)
     end || N <- Ns].

clamp_holds_the_bounds_test() ->
    ?assertEqual(5, fixed:clamp(5, 0, 10)),
    ?assertEqual(0, fixed:clamp(-3, 0, 10)),
    ?assertEqual(10, fixed:clamp(99, 0, 10)),
    ?assertEqual(-4, fixed:clamp(-9, -4, 4)).

%% ⚠ IT IS THE FLOOR, NOT THE NEAREST, AND THE INEXACT CASE IS TESTED BECAUSE OF
%% IT. sqrt(41) is 6.403 and this answers 6. Every use of it in the engine is a
%% comparison against a threshold, so a consistent floor is right and a rounding
%% that sometimes went up would make a hit radius half a unit larger in some
%% directions than others.
mag3_is_the_length_test() ->
    ?assertEqual(5, fixed:mag3(3, 4, 0)),
    ?assertEqual(0, fixed:mag3(0, 0, 0)),
    ?assertEqual(6, fixed:mag3(-3, 4, 4)),
    ?assertEqual(6, trunc(math:sqrt(41))).

a_vector_shorter_than_the_limit_is_untouched_test() ->
    ?assertEqual({3, 4, 0}, fixed:scale_to(3, 4, 0, 100)).

%% ⚠ THE TEST THAT STOPS THE FREE DIAGONAL. Clamping each axis to the limit
%% independently would let a drone commanding the limit on all three axes get
%% root three times the thrust, available only diagonally. A population finds
%% that inside a generation.
a_long_vector_is_shortened_as_a_whole_test() ->
    {X, Y, Z} = fixed:scale_to(1000, 1000, 1000, 1000),
    ?assert(fixed:mag3(X, Y, Z) =< 1000),
    %% and it kept its direction: the three components stay equal
    ?assertEqual(X, Y),
    ?assertEqual(Y, Z).

a_zero_vector_scales_to_zero_rather_than_dividing_by_it_test() ->
    ?assertEqual({0, 0, 0}, fixed:scale_to(0, 0, 0, 100)).

negatives_keep_their_sign_when_shortened_test() ->
    {X, Y, Z} = fixed:scale_to(-3000, 0, 4000, 500),
    ?assert(X < 0),
    ?assertEqual(0, Y),
    ?assert(Z > 0),
    ?assert(fixed:mag3(X, Y, Z) =< 500).
