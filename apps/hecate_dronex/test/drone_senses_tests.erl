%% @doc What a drone can perceive, and what it deliberately cannot.
-module(drone_senses_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).

%% One drone at the middle of the arena facing east, plus whatever else is given.
world(Others) ->
    airspace:new([{a, attacker, 500 * ?M, 500 * ?M, 100 * ?M, 0} | Others]).

self_of(A) -> airspace:drone(A, a).
rest_of(A) -> [D || D <- airspace:drones(A), D#drone.id =/= a].

vec(A) -> drone_senses:sense(self_of(A), rest_of(A), []).

%% The first contact slot, which is channels 9 to 15.
slot1(V) -> lists:sublist(V, 9, 7).

bearing_cos(V) -> lists:nth(1, slot1(V)).
bearing_sin(V) -> lists:nth(2, slot1(V)).
elevation(V) -> lists:nth(3, slot1(V)).
range_of(V) -> lists:nth(5, slot1(V)).
closing(V) -> lists:nth(6, slot1(V)).
affiliation(V) -> lists:nth(7, slot1(V)).

%%==============================================================================
%% Shape
%%==============================================================================

the_vector_is_the_declared_width_test() ->
    ?assertEqual(drone_senses:channels(), length(vec(world([])))),
    ?assertEqual(41, length(vec(world([])))).

%% ⚠ EVERY CHANNEL IN MINUS ONE TO ONE. A network whose inputs differ by orders
%% of magnitude spends its first generations learning the scale rather than the
%% task, and the drift would be invisible: the population would still improve,
%% just slower, for a reason nothing reports.
every_channel_is_bounded_test() ->
    A = world([{b, defender, 560 * ?M, 520 * ?M, 140 * ?M, 128},
               {c, attacker, 505 * ?M, 500 * ?M, 100 * ?M, 0}]),
    [?assert(is_float(C) andalso C >= -1.0 andalso C =< 1.0) || C <- vec(A)].

an_empty_sky_reads_as_zeros_test() ->
    V = vec(world([])),
    Contacts = lists:sublist(V, 9, 21),
    ?assertEqual(lists:duplicate(21, 0.0), Contacts).

%%==============================================================================
%% Proprioception
%%==============================================================================

a_full_battery_and_full_health_read_as_one_test() ->
    V = vec(world([])),
    ?assertEqual(1.0, lists:nth(1, V)),
    ?assertEqual(1.0, lists:nth(6, V)).

altitude_is_a_fraction_of_the_ceiling_test() ->
    #{arena_z := Z} = airspace:limits(),
    V = vec(world([])),
    ?assertEqual(100 * ?M / Z, lists:nth(4, V)).

%% ⚠ THE THREE SELF-DIAGNOSIS CHANNELS, WHICH ARE WHY RETREAT NEEDED A MECHANISM
%% AND NOT A SENSOR. Battery, health and damage-this-tick were already here; what
%% was missing was anywhere to go and a payoff for going.
being_hurt_shows_up_immediately_test() ->
    A0 = world([]),
    Hurt = A0#arena{drones = [(self_of(A0))#drone{health = 5000, damage_taken = 2500}]},
    V = drone_senses:sense(self_of(Hurt), [], []),
    ?assertEqual(0.5, lists:nth(6, V)),
    ?assertEqual(0.25, lists:nth(8, V)).

%%==============================================================================
%% Contacts
%%==============================================================================

%% Dead ahead: the cosine is one and the sine is zero. Both are dot products, so
%% there is no `atan2` anywhere on the match path.
a_contact_dead_ahead_reads_as_straight_ahead_test() ->
    V = vec(world([{b, defender, 600 * ?M, 500 * ?M, 100 * ?M, 0}])),
    ?assertEqual(1.0, bearing_cos(V)),
    ?assertEqual(0.0, bearing_sin(V)).

%% ⚠ TWO CHANNELS RATHER THAN ONE ANGLE, and this is the pair of tests that says
%% why: left and right differ in the SIGN of the sine while the cosine agrees, so
%% there is no discontinuity anywhere as a target crosses the nose.
a_contact_to_the_left_and_one_to_the_right_differ_only_in_sign_test() ->
    Left = vec(world([{b, defender, 570 * ?M, 530 * ?M, 100 * ?M, 0}])),
    Right = vec(world([{b, defender, 570 * ?M, 470 * ?M, 100 * ?M, 0}])),
    ?assert(bearing_sin(Left) > 0.0),
    ?assert(bearing_sin(Right) < 0.0),
    ?assertEqual(bearing_cos(Left), bearing_cos(Right)),
    ?assertEqual(bearing_sin(Left), -bearing_sin(Right)).

a_contact_above_reads_as_above_test() ->
    V = vec(world([{b, defender, 600 * ?M, 500 * ?M, 200 * ?M, 0}])),
    ?assert(elevation(V) > 0.0).

%% ⚠ A DRONE IS BLIND BEHIND, AND THAT IS A FEATURE. A 120 degree field of view
%% is what an airframe carries, and the blind arc is what makes yaw expensive,
%% makes being approached from behind possible, and gives the comms channel at
%% item 6 something to be for. A drone that saw everywhere would have no reason
%% to tell anybody anything.
a_contact_behind_is_invisible_test() ->
    V = vec(world([{b, defender, 400 * ?M, 500 * ?M, 100 * ?M, 0}])),
    ?assertEqual(0.0, range_of(V)),
    ?assertEqual(0.0, affiliation(V)).

%% ⚠ THE FAR CORNER, NOT THE FAR WALL, AND THE FIRST VERSION OF THIS TEST GOT IT
%% WRONG. From the middle of a 1000 m arena the far wall is only 500 m away,
%% which is INSIDE the 600 m sensor range, so a target parked against it is
%% plainly visible. The arena's longest diagonal from the centre is about 735 m,
%% so the corner is the only place a contact can be out of range at all.
a_contact_beyond_sensor_range_is_invisible_test() ->
    #{lock_range := R} = airspace:limits(),
    ?assertEqual(R, drone_senses:range()),
    Corner = fixed:mag3(480 * ?M, 480 * ?M, 180 * ?M),
    ?assert(Corner > R),
    V = vec(world([{b, defender, 980 * ?M, 980 * ?M, 280 * ?M, 0}])),
    ?assertEqual(0.0, range_of(V)).

%% Nearer contacts read as a smaller range, which is the direction a controller
%% has to get right and the one an inverted scale would silently flip.
range_grows_with_distance_test() ->
    Near = vec(world([{b, defender, 520 * ?M, 500 * ?M, 100 * ?M, 0}])),
    Far = vec(world([{b, defender, 700 * ?M, 500 * ?M, 100 * ?M, 0}])),
    ?assert(range_of(Near) < range_of(Far)),
    ?assert(range_of(Near) > 0.0).

friend_and_foe_are_opposite_test() ->
    Foe = vec(world([{b, defender, 600 * ?M, 500 * ?M, 100 * ?M, 0}])),
    Friend = vec(world([{b, attacker, 600 * ?M, 500 * ?M, 100 * ?M, 0}])),
    ?assertEqual(-1.0, affiliation(Foe)),
    ?assertEqual(1.0, affiliation(Friend)).

%% Positive when the gap is closing, which is what a doppler-style reading gives.
closing_is_positive_when_the_gap_shrinks_test() ->
    A0 = world([{b, defender, 600 * ?M, 500 * ?M, 100 * ?M, 128}]),
    Toward = moving(A0, b, -20000),
    Away = moving(A0, b, 20000),
    ?assert(closing(drone_senses:sense(self_of(Toward), rest_of(Toward), [])) > 0.0),
    ?assert(closing(drone_senses:sense(self_of(Away), rest_of(Away), [])) < 0.0).

moving(#arena{drones = Ds} = A, Id, Vx) ->
    A#arena{drones = [set_vx(D, Id, Vx) || D <- Ds]}.

set_vx(#drone{id = Id} = D, Id, Vx) -> D#drone{vx = Vx};
set_vx(D, _Id, _Vx) -> D.

%% Only the three nearest are reported, so a swarm does not widen the input
%% vector and a controller bred against three contacts stays flyable in a crowd.
only_the_three_nearest_are_reported_test() ->
    Crowd = [{list_to_atom([C]), defender, (510 + N * 5) * ?M, 500 * ?M, 100 * ?M, 0}
             || {C, N} <- lists:zip("bcdef", lists:seq(1, 5))],
    V = vec(world(Crowd)),
    Ranges = [lists:nth(5, lists:sublist(V, 9 + (N - 1) * 7, 7)) || N <- [1, 2, 3]],
    ?assertEqual(lists:sort(Ranges), Ranges),
    ?assert(lists:all(fun (R) -> R > 0.0 end, Ranges)).

%%==============================================================================
%% Comms
%%==============================================================================

%% ⚠ THIS WAS THE ITEM 6 REMINDER AND ITEM 6 HAS LANDED. Until comms existed it
%% asserted twelve reserved zeros, so that the width could not quietly grow later
%% and invalidate every genome bred and persisted at item 5. It now asserts the
%% other half of the same bargain: the width did NOT change, and the channels
%% carry `radio''s output rather than a placeholder.
the_comms_channels_are_the_radio_test() ->
    ?assertEqual(12, drone_senses:comms_width()),
    ?assertEqual(radio:width(), drone_senses:comms_width()),
    ?assertEqual(lists:duplicate(12, 0.0),
                 lists:sublist(vec(world([])), 30, 12)),
    %% A saturated bank reads one, and one drone at full volume reads an eighth,
    %% so the COUNT survives normalisation up to the saturation point.
    #{heard_max := Max, signal_max := S} = airspace:limits(),
    Loud = [Max | lists:duplicate(11, 0)],
    ?assertEqual(1.0, hd(lists:sublist(sensed(Loud), 30, 12))),
    ?assertEqual(S / Max, hd(lists:sublist(sensed([S | lists:duplicate(11, 0)]), 30, 12))).

sensed(Comms) ->
    A = world([]),
    drone_senses:sense(self_of(A), [], Comms).

%% And the width is enforced rather than assumed: a wrong-length comms list is
%% silence, not a shifted vector.
a_malformed_comms_list_is_silence_test() ->
    A = world([]),
    ?assertEqual(vec(A), drone_senses:sense(self_of(A), [], [1, 2, 3])).
