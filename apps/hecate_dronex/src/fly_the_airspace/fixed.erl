%% @doc The integer arithmetic the match path is allowed to use. PURE.
%%
%% THIS EXISTS SO A FIGHT IS THE SAME FIGHT ON EVERY MACHINE. design/
%% DESIGN_THE_AIRSPACE.md requires a raid to be a pure function of its start
%% state, byte for byte, so that the island that flew a sortie can check what the
%% island that hosted it published. Float `+', `*' and `-' are exact under
%% IEEE754 and BEAM uses SSE2 doubles with no extended precision, so the ONLY
%% source of divergence in a forward pass or a flight step is a transcendental,
%% and every transcendental here is a table lookup.
%%
%% ⚠ NO `math:' CALL MAY EVER APPEAR IN THIS MODULE OR ANY MODULE IT SERVES.
%% `airspace_determinism_tests' asserts that structurally, over the compiled call
%% graph, so adding one breaks a test rather than quietly making a published
%% fight unverifiable.
%%
%% ==========================================================================
%% THE UNITS, CHOSEN SO THE ARITHMETIC IS EXACT RATHER THAN NEARLY EXACT
%% ==========================================================================
%%
%% A tick is 50 ms, so there are 20 in a second. Everything below follows from
%% wanting a whole number of position units per tick at a round speed.
%%
%%     position       1 metre        = 20480 units      (resolution ~0.049 mm)
%%     velocity       1 m/s          = 1024 units/tick  (= 20480/20, exact)
%%     acceleration   1 m/s^2        = 51.2 units/tick^2
%%
%% ⚠ THE ACCELERATION UNIT IS NOT A WHOLE NUMBER OF m/s^2 AND THAT IS THE
%% TRADE. Position and velocity are exact, which is what integration needs;
%% acceleration is the derived one, so a physics constant is chosen to land on an
%% integer rather than rounded after the fact. 20 m/s^2 is exactly 1024 and
%% gravity is 502, which is 9.8046875 m/s^2. The model's gravity IS that number.
%% It is not 9.81 approximated; it is exact, and it is stated rather than hidden.
-module(fixed).

-include("sine_table.hrl").

%% Units
-export([per_metre/0, per_ms/0, per_accel/0, ticks_per_second/0]).
%% Trigonometry on binary angles
-export([sin/1, cos/1, wrap/1]).
%% Arithmetic
-export([isqrt/1, clamp/3, mag3/3, scale_to/4, at_length/4, along/5]).

%% 20480 units per metre. See the module doc for why this and not a power of two.
-define(PER_METRE, 20480).
-define(TICKS_PER_SECOND, 20).
%% Velocity: units per TICK, so integration is `Pos + Vel' with no division and
%% therefore no truncation bias. A divide-per-tick would drag everything slowly
%% toward zero and look like drag that nobody wrote.
-define(PER_MS, 1024).
%% Acceleration: units per tick per tick, times ten so the doc can state it
%% without a fraction. 1 m/s^2 = 512 tenths.
-define(PER_ACCEL_TENTHS, 512).

-define(SIN_SCALE, 32768).
-define(TURN, 256).

%% @doc Position units in one metre.
-spec per_metre() -> pos_integer().
per_metre() -> ?PER_METRE.

%% @doc Velocity units, per tick, in one metre per second.
-spec per_ms() -> pos_integer().
per_ms() -> ?PER_MS.

%% @doc Acceleration units, per tick squared, in one TENTH of a metre per second
%% squared. Tenths because the unit is 51.2 and a function returning 51 would be
%% a rounding nobody asked for.
-spec per_accel() -> pos_integer().
per_accel() -> ?PER_ACCEL_TENTHS.

-spec ticks_per_second() -> pos_integer().
ticks_per_second() -> ?TICKS_PER_SECOND.

%%==============================================================================
%% Angles
%%==============================================================================

%% @doc Fold any integer onto 0..255.
%%
%% BINARY ANGLES RATHER THAN DEGREES OR RADIANS, because a full turn is 256 and
%% therefore wraps for free on `rem', with no rounding anywhere near the wrap
%% point. A heading in degrees needs a modulo by 360 that is exact only by
%% accident, and one in radians needs a float.
-spec wrap(integer()) -> 0..255.
wrap(A) -> ((A rem ?TURN) + ?TURN) rem ?TURN.

%% @doc sin of a binary angle, scaled by 32768.
-spec sin(integer()) -> integer().
sin(A) -> element(wrap(A) + 1, ?SIN_TABLE).

%% @doc cos of a binary angle, scaled by 32768. A quarter turn is 64.
-spec cos(integer()) -> integer().
cos(A) -> sin(A + 64).

%%==============================================================================
%% Arithmetic
%%==============================================================================

%% @doc Integer square root, floor. Deterministic on every machine.
%%
%% Newton's method on integers. `math:sqrt/1' would be one float call and is
%% exactly what this module exists to keep off the match path.
-spec isqrt(non_neg_integer()) -> non_neg_integer().
isqrt(N) when N < 2 -> N;
isqrt(N) -> isqrt_step(N, N div 2).

isqrt_step(N, X) -> settled(N, X, (X + N div X) div 2).

settled(_N, X, Y) when Y >= X -> X;
settled(N, _X, Y) -> isqrt_step(N, Y).

-spec clamp(integer(), integer(), integer()) -> integer().
clamp(V, Lo, _Hi) when V < Lo -> Lo;
clamp(V, _Lo, Hi) when V > Hi -> Hi;
clamp(V, _Lo, _Hi) -> V.

%% @doc Length of a 3-vector, floor.
-spec mag3(integer(), integer(), integer()) -> non_neg_integer().
mag3(X, Y, Z) -> isqrt(X * X + Y * Y + Z * Z).

%% @doc Shorten a 3-vector to at most `Max', leaving it alone if it is already
%% shorter.
%%
%% ⚠ SCALED AS A WHOLE, NEVER PER AXIS. Clamping each axis independently lets a
%% drone commanding full thrust on all three exceed its limit by a factor of
%% root three, which is a free 73% of thrust available only diagonally. A
%% population would find that within a generation and the airframe would stop
%% meaning anything.
-spec scale_to(integer(), integer(), integer(), non_neg_integer()) ->
    {integer(), integer(), integer()}.
scale_to(X, Y, Z, Max) -> shortened(X, Y, Z, Max, mag3(X, Y, Z)).

shortened(X, Y, Z, Max, Mag) when Mag =< Max -> {X, Y, Z};
shortened(_X, _Y, _Z, _Max, 0) -> {0, 0, 0};
shortened(X, Y, Z, Max, Mag) ->
    {X * Max div Mag, Y * Max div Mag, Z * Max div Mag}.

%% @doc Set a 3-vector to exactly `Len', lengthening it if it is short.
%%
%% Distinct from `scale_to/4', which only ever shortens. A guided munition holds
%% a constant speed and steers, so after every turn its velocity has to be put
%% back to exactly that speed rather than merely capped: capping alone would let
%% a steering correction bleed speed away, and an interceptor that slows down
%% every time it turns is a weapon that punishes the target for manoeuvring in
%% the wrong direction.
-spec at_length(integer(), integer(), integer(), non_neg_integer()) ->
    {integer(), integer(), integer()}.
at_length(X, Y, Z, Len) -> stretched(X, Y, Z, Len, mag3(X, Y, Z)).

stretched(_X, _Y, _Z, _Len, 0) -> {0, 0, 0};
stretched(X, Y, Z, Len, Mag) -> {X * Len div Mag, Y * Len div Mag, Z * Len div Mag}.

%% @doc How far a vector points along a heading, as a fraction of its own length,
%% scaled by 32768. One means dead ahead, zero means abeam, minus one behind.
%%
%% ⚠ THIS IS HOW A CONE IS TESTED WITHOUT AN INVERSE TRIGONOMETRIC FUNCTION, and
%% there is no `atan2' anywhere in this repository for exactly that reason. The
%% dot product of a unit heading with a unit direction IS the cosine of the angle
%% between them, so `is it within 45 degrees of my nose' becomes a comparison
%% against `cos(32)' and stays exact integer arithmetic.
%%
%% The heading is horizontal, because yaw is the only attitude a drone has.
-spec along(integer(), integer(), integer(), integer(), 0..255) -> integer().
along(Dx, Dy, Dz, _Len, _Yaw) when Dx =:= 0, Dy =:= 0, Dz =:= 0 -> 0;
along(Dx, Dy, _Dz, Len, Yaw) -> projected(Dx * cos(Yaw) + Dy * sin(Yaw), Len).

projected(_Dot, 0) -> 0;
projected(Dot, Len) -> Dot div Len.
