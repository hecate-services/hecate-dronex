%% @doc What a drone can perceive. PURE, and the boundary is here.
%%
%% THIS EXISTS SO A CONTROLLER SEES WHAT AN AIRFRAME COULD SEE AND NOTHING ELSE.
%% Every channel below is a quantity a real drone produces from an IMU, a
%% barometer, a battery monitor and a forward sensor. That is charter rule 7 and
%% it is what makes the ONNX export at item 12 a meaningful test rather than a
%% demonstration: a channel only a simulator can compute would make the exported
%% controller unflyable.
%%
%% ==========================================================================
%% ⚠ NO CHANNEL NAMES A TACTIC. CHARTER RULE 8.
%% ==========================================================================
%%
%% There is no `am I flanking', no `should I retreat', no `am I locked on'. Each
%% of those is derivable from what is here, and handing one over would be handing
%% over the answer to the question this repository exists to ask. The rule bites
%% hardest at `am I locked on', which would have been the most natural thing in
%% the world to add when the interceptor landed: bearing, range and affiliation
%% already say it, so a controller has to learn it.
%%
%% ==========================================================================
%% ⚠ THE CONE IS 120 DEGREES, SO A DRONE IS BLIND BEHIND
%% ==========================================================================
%%
%% A forward sensor is what an airframe carries, and the blind arc is not a
%% simplification to apologise for: it is what makes yaw expensive, what makes
%% being approached from behind a real thing that can happen, and what gives the
%% comms channel at item 6 something to be FOR. A drone that could see
%% everywhere would have no reason to tell anybody anything.
-module(drone_senses).

-include("airspace.hrl").

-export([sense/3, channels/0, contacts/0, contact_width/0, comms_width/0]).
-export([range/0, reach_fraction/0, cone_cos/0, contact/2, nearest_hostile/1, self_reading/1]).

%% 8 proprioception + 3 contacts x 7 + 12 comms.
-define(PROPRIOCEPTION, 8).
-define(CONTACTS, 3).
-define(CONTACT_WIDTH, 7).
-define(COMMS_WIDTH, 12).

%% 600 m, matching the seeker. A sensor that saw further than the weapon could
%% reach would report contacts nothing could be done about.
-define(SENSE_RANGE, 12288000).
%% cos(60 degrees) at the 32768 scale: a 120 degree field of view.
-define(CONE_COS, 16384).

-spec channels() -> pos_integer().
channels() -> ?PROPRIOCEPTION + ?CONTACTS * ?CONTACT_WIDTH + ?COMMS_WIDTH.

-spec contacts() -> pos_integer().
contacts() -> ?CONTACTS.

-spec contact_width() -> pos_integer().
contact_width() -> ?CONTACT_WIDTH.

-spec comms_width() -> pos_integer().
comms_width() -> ?COMMS_WIDTH.

-spec range() -> pos_integer().
range() -> ?SENSE_RANGE.

%% @doc How far the guided interceptor reaches, in the units a contact's `range'
%% is reported in: a fraction of sensor range, where 1.0 is the far edge of sight.
%%
%% ⚠ THIS EXISTS SO NOBODY WRITES `0.1' AGAIN, AND ON 2026-08-10 IT PAID FOR
%% ITSELF. On 2026-08-09 the interceptor's reach went from 600 m to 60 m, and the
%% launch gates in `drone_drills' and `drone_trials' were given the ceiling
%% `R =< 0.1' in three places to match. That literal meant "60 m" only for as
%% long as `INTERCEPTOR_TTL' stayed 15 — it is 30 now, for 120 m, and every gate
%% followed with no edit — and NOTHING connected the two: change the weapon and
%% all six curriculum rungs and
%% all six trial rungs quietly start firing into fuel they do not have, spending
%% a magazine of two before contact. The ladders would not fail, they would just
%% get easier, which is the failure mode a benchmark cannot survive.
%%
%% ⚠⚠ AND IT IS DERIVED RATHER THAN A SECOND CONSTANT, because a second constant
%% is the same bug with a better name. Reach is `speed * ttl' exactly, so this
%% reads both from `airspace:limits/0' and cannot disagree with the weapon.
%% `senses_tests' pins the relationship rather than the value.
-spec reach_fraction() -> float().
reach_fraction() ->
    #{interceptor_speed := S, interceptor_ttl := Ttl} = airspace:limits(),
    S * Ttl / ?SENSE_RANGE.

-spec cone_cos() -> integer().
cone_cos() -> ?CONE_COS.

%% @doc The input vector for one drone, as floats in roughly minus one to one.
%%
%% ⚠ IT TAKES THE DRONE AND THE OTHER DRONES, NEVER THE ARENA. The arena carries
%% munitions in flight and every drone's exact state, and a function that
%% received it could reach them by accident. The defence is the argument list,
%% which the compiler checks; a comment saying "do not look at the munitions"
%% would not survive a refactor.
%%
%% ⚠⚠ AND THERE IS NO INCOMING-FIRE CHANNEL, WHICH IS A REAL LIMITATION RATHER
%% THAN AN OVERSIGHT. A drone cannot see a munition coming at it. The only
%% proprioception of being shot is `damage`, which also conflates walls, the
%% ground and collisions. Any claim about evasion has to respect that: what can
%% be learned here is avoiding places where being shot is likely, not dodging a
%% shot in flight.
-spec sense(#drone{}, [#drone{}], [integer()]) -> [float()].
sense(#drone{} = Self, Others, Comms) ->
    own(Self) ++ seen(Self, Others) ++ heard(Comms).

%%==============================================================================
%% Proprioception
%%==============================================================================

own(#drone{} = D) ->
    #{start_battery := B, start_health := H, arena_z := Z,
      max_accel := A, drag_div := Div, max_yaw_rate := R} = airspace:limits(),
    Terminal = fixed:isqrt(A * Div),
    [unit(D#drone.battery, B),
     unit(fixed:mag3(D#drone.vx, D#drone.vy, D#drone.vz), Terminal),
     signed(D#drone.vz, Terminal),
     unit(D#drone.z, Z),
     unit(edge_distance(D), lateral_half()),
     unit(D#drone.health, H),
     signed(D#drone.yaw_rate, R),
     unit(D#drone.damage_taken, H)].

%% How far the nearest lateral wall is. The ground and the ceiling are reported
%% by altitude, and are a different kind of hazard.
edge_distance(#drone{x = X, y = Y}) ->
    #{arena_x := Ax, arena_y := Ay} = airspace:limits(),
    lists:min([X, Ax - X, Y, Ay - Y]).

lateral_half() ->
    #{arena_x := Ax} = airspace:limits(),
    Ax div 2.

%%==============================================================================
%% Contacts
%%==============================================================================

seen(#drone{} = Self, Others) ->
    Near = lists:sublist(lists:keysort(1, visible(Self, Others)), ?CONTACTS),
    lists:append([reading(Self, C) || {_R, C} <- Near])
        ++ lists:duplicate((?CONTACTS - length(Near)) * ?CONTACT_WIDTH, empty()).

visible(#drone{} = Self, Others) ->
    [{R, O} || O <- Others, O#drone.id =/= Self#drone.id,
               R <- [distance(Self, O)], R > 0, R =< ?SENSE_RANGE,
               in_cone(Self, O, R)].

distance(#drone{x = X, y = Y, z = Z}, #drone{x = Ox, y = Oy, z = Oz}) ->
    fixed:mag3(Ox - X, Oy - Y, Oz - Z).

in_cone(#drone{x = X, y = Y, z = Z, yaw = Yaw}, #drone{x = Ox, y = Oy, z = Oz}, R) ->
    fixed:along(Ox - X, Oy - Y, Oz - Z, R, Yaw) >= ?CONE_COS.

%% ⚠ BEARING AS A SINE AND A COSINE RATHER THAN AS AN ANGLE. A single bearing
%% channel jumps from one extreme to the other as a target crosses the nose, and
%% a network has to spend capacity learning that the jump is not real. Two
%% channels have no discontinuity anywhere.
%%
%% ⚠⚠ AND BOTH ARE DOT PRODUCTS, SO THERE IS STILL NO `atan2' ON THE MATCH PATH.
%% The cosine is the projection along the nose and the sine is the cross product
%% with it, both exact integer arithmetic.
reading(#drone{x = X, y = Y, z = Z, yaw = Yaw, vx = Vx, vy = Vy, vz = Vz} = Self,
        #drone{x = Ox, y = Oy, z = Oz, vx = Ovx, vy = Ovy, vz = Ovz} = O) ->
    Dx = Ox - X, Dy = Oy - Y, Dz = Oz - Z,
    R = distance(Self, O),
    Flat = fixed:isqrt(Dx * Dx + Dy * Dy),
    [scaled(fixed:along(Dx, Dy, Dz, R, Yaw)),
     scaled(cross(Dx, Dy, R, Yaw)),
     signed(Dz, R),
     unit(Flat, R),
     unit(R, ?SENSE_RANGE),
     closing({Dx, Dy, Dz}, {Ovx - Vx, Ovy - Vy, Ovz - Vz}, R),
     affiliation(Self, O)].

%% The z component of nose x direction: positive to the left of the nose.
cross(Dx, Dy, R, Yaw) -> project(fixed:cos(Yaw) * Dy - fixed:sin(Yaw) * Dx, R).

project(_N, 0) -> 0;
project(N, R) -> N div R.

%% Positive when the gap is closing. Derived from relative velocity along the
%% line of sight, which is what a doppler-style reading gives.
closing(_D, _Rel, 0) -> 0.0;
closing({Dx, Dy, Dz}, {Rx, Ry, Rz}, R) ->
    #{max_accel := A, drag_div := Div} = airspace:limits(),
    signed(-((Rx * Dx + Ry * Dy + Rz * Dz) div R), 2 * fixed:isqrt(A * Div)).

%% ⚠ FRIEND OR FOE IS GIVEN, AND IT IS THE ONE PIECE OF PRIVILEGED INFORMATION
%% HERE. A real system gets it from an identify-friend-or-foe transponder, which
%% is why it is defensible; but it is also why the merged-comms-bank experiment
%% in DESIGN_DRONES_THAT_TALK is interesting, because there deception becomes
%% possible precisely by NOT giving it.
affiliation(#drone{side = S}, #drone{side = S}) -> 1.0;
affiliation(_Self, _O) -> -1.0.

%% An empty slot is all zeros. Range zero is not a contact at zero metres, it is
%% no contact, and the affiliation channel being zero rather than plus or minus
%% one is what makes the two distinguishable.
empty() -> 0.0.

%%==============================================================================
%% Comms
%%==============================================================================

%% ⚠ TWELVE CHANNELS THAT ARE ZERO UNTIL ITEM 6, AND THAT IS DELIBERATE RATHER
%% THAN A STUB. The genome's width is fixed by the channel count, so growing it
%% at item 6 would invalidate every genome bred and persisted at item 5. Carrying
%% the width from the start costs twelve zeros per evaluation and saves throwing
%% a roster away. `drone_senses_tests' asserts they are currently zero, which is
%% a guard that has to be updated when comms arrive rather than a lie that rots.
heard(Comms) when length(Comms) =:= ?COMMS_WIDTH -> [scaled_heard(C) || C <- Comms];
heard(_Comms) -> lists:duplicate(?COMMS_WIDTH, 0.0).

%% Divided by what a saturated sky sounds like, so one drone at full volume reads
%% about an eighth and eight of them read one. The COUNT is preserved up to the
%% saturation point, which is the whole reason the bank is a sum.
scaled_heard(C) ->
    #{heard_max := Max} = airspace:limits(),
    clampf(C / Max, -1.0, 1.0).

%%==============================================================================
%% Scaling
%%==============================================================================

%% Everything reaches the network in roughly minus one to one, because a network
%% whose inputs differ by orders of magnitude spends its first generations
%% learning the scale rather than the task.
unit(_V, 0) -> 0.0;
unit(V, Max) -> clampf(V / Max, 0.0, 1.0).

signed(_V, 0) -> 0.0;
signed(V, Max) -> clampf(V / Max, -1.0, 1.0).

scaled(N) -> clampf(N / 32768.0, -1.0, 1.0).

clampf(V, Lo, _Hi) when V < Lo -> Lo;
clampf(V, _Lo, Hi) when V > Hi -> Hi;
clampf(V, _Lo, _Hi) -> V.

%%==============================================================================
%% Reading a vector back
%%==============================================================================

%% @doc Contact `N' of a sensed vector, or `undefined' for an empty slot.
%%
%% ⚠ EXPORTED SO THE SCRIPTED DRILLS SEE EXACTLY WHAT AN EVOLVED CONTROLLER SEES,
%% AND THAT IS A FAIRNESS PROPERTY RATHER THAN A CONVENIENCE. A drill written
%% against the arena directly would know where its opponent is when a genome
%% cannot, including behind it, and every benchmark number would be measured
%% against an opponent with better eyes. Making the drills read the same vector
%% makes the limit structural.
-spec contact([float()], pos_integer()) -> map() | undefined.
contact(V, N) when N >= 1, N =< ?CONTACTS ->
    slot(lists:sublist(V, ?PROPRIOCEPTION + (N - 1) * ?CONTACT_WIDTH + 1,
                       ?CONTACT_WIDTH)).

%% Range zero is the empty marker: a real contact is at least one unit away,
%% because `visible/2' drops anything at distance zero.
%%
%% ⚠ `+0.0' RATHER THAN `0.0', because from OTP 27 a bare `0.0' pattern no longer
%% also matches `-0.0'. Nothing here produces a negative zero today, and writing
%% the intent explicitly is what stops that being a silent assumption.
slot([_C, _S, _E, _F, +0.0, _Cl, _A]) -> undefined;
slot([C, S, E, F, R, Cl, A]) ->
    #{bearing_cos => C, bearing_sin => S, elevation => E, flat => F,
      range => R, closing => Cl, affiliation => A}.

%% @doc The nearest visible hostile in a sensed vector, or `undefined'.
%%
%% Contacts arrive sorted by range, so the first hostile slot is the nearest one.
-spec nearest_hostile([float()]) -> map() | undefined.
nearest_hostile(V) -> first_hostile([contact(V, N) || N <- lists:seq(1, ?CONTACTS)]).

first_hostile([#{affiliation := A} = C | _Rest]) when A < 0.0 -> C;
first_hostile([_Other | Rest]) -> first_hostile(Rest);
first_hostile([]) -> undefined.

%% @doc The eight proprioception channels of a sensed vector, by name.
%%
%% Exported so a drill can read its own state without indexing into the vector.
%% A magic index is a number that silently means something else the day a channel
%% is inserted, and the proprioception block is the one most likely to grow.
-spec self_reading([float()]) -> map().
self_reading([Bat, Speed, Climb, Alt, Edge, Health, Yaw, Damage | _Rest]) ->
    #{battery => Bat, speed => Speed, climb => Climb, altitude => Alt,
      edge => Edge, health => Health, yaw_rate => Yaw, damage => Damage}.
