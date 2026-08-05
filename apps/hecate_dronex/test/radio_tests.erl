%% @doc What the radio does, and what it deliberately refuses to do.
-module(radio_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).

d(Id, Side, Xm, Signal) ->
    #drone{id = Id, side = Side, x = Xm * ?M, y = 0, z = 100 * ?M, signal = Signal}.

self_at(Xm) -> d(me, attacker, Xm, [0, 0, 0, 0]).

%%==============================================================================
%% Shape
%%==============================================================================

the_width_is_three_banks_of_four_test() ->
    ?assertEqual(3, radio:banks()),
    ?assertEqual(12, radio:width()),
    ?assertEqual(lists:duplicate(12, 0), radio:silence()),
    %% And it is the width the senses reserved at item 3, which is the whole
    %% reason a genome bred before comms still loads after them.
    ?assertEqual(drone_senses:comms_width(), radio:width()).

a_drone_alone_hears_nothing_test() ->
    ?assertEqual(radio:silence(), radio:heard(self_at(0), [])).

%%==============================================================================
%% Which bank
%%==============================================================================

friend_and_foe_land_in_different_banks_test() ->
    Friend = d(f, attacker, 10, [1, 2, 3, 4]),
    Foe = d(e, defender, 10, [5, 6, 7, 8]),
    ?assertEqual([1, 2, 3, 4] ++ [5, 6, 7, 8] ++ [0, 0, 0, 0],
                 radio:heard(self_at(0), [Friend, Foe])).

%% ⚠ ZERO UNTIL ITEM 8 AND CARRIED ANYWAY: the ground bank has no transmitter yet.
the_ground_bank_is_silent_until_the_static_defence_lands_test() ->
    Loud = [d(a, attacker, 10, [500, 500, 500, 500]),
            d(b, defender, 10, [500, 500, 500, 500])],
    ?assertEqual([0, 0, 0, 0], lists:sublist(radio:heard(self_at(0), Loud), 9, 4)).

%%==============================================================================
%% The sum
%%==============================================================================

%% ⚠ THE MAGNITUDE IS A COUNT, which is why this is a sum and not a mean. Three
%% drones saying the same thing are three times as loud as one, and that is the
%% only way a controller can tell how many are shouting.
three_friends_saying_the_same_thing_are_three_times_as_loud_test() ->
    Ds = [d(N, attacker, 10, [100, 0, -50, 0]) || N <- [a, b, c]],
    ?assertEqual([300, 0, -150, 0], lists:sublist(radio:heard(self_at(0), Ds), 1, 4)).

opposed_signals_cancel_test() ->
    Ds = [d(a, attacker, 10, [100, 0, 0, 0]), d(b, attacker, 10, [-100, 0, 0, 0])],
    ?assertEqual([0, 0, 0, 0], lists:sublist(radio:heard(self_at(0), Ds), 1, 4)).

%% A large swarm saturates rather than handing a controller a number it has never
%% seen at any other swarm size.
a_loud_crowd_saturates_rather_than_overflowing_test() ->
    #{heard_max := Max, signal_max := S} = airspace:limits(),
    Ds = [d(N, attacker, 10, [S, -S, 0, 0]) || N <- lists:seq(1, 40)],
    ?assertEqual([Max, -Max, 0, 0], lists:sublist(radio:heard(self_at(0), Ds), 1, 4)),
    %% And the saturation point is reachable by a plausible swarm, not a
    %% theoretical one: eight drones at full volume is the ceiling.
    ?assertEqual(8, Max div S).

%%==============================================================================
%% Who is audible
%%==============================================================================

%% Broadcast has a horizon, so a swarm that spreads out loses contact. That is a
%% cost of dispersing rather than a free coordination channel.
range_is_finite_test() ->
    #{comms_range := R} = airspace:limits(),
    Near = d(n, attacker, R div ?M - 1, [7, 0, 0, 0]),
    Far = d(f, attacker, R div ?M + 1, [9, 0, 0, 0]),
    ?assertEqual([7, 0, 0, 0], lists:sublist(radio:heard(self_at(0), [Near, Far]), 1, 4)).

the_dead_and_the_departed_are_silent_test() ->
    Dead = (d(a, attacker, 10, [100, 0, 0, 0]))#drone{dead = true},
    Gone = (d(b, attacker, 10, [100, 0, 0, 0]))#drone{withdrawn = true},
    ?assertEqual(radio:silence(), radio:heard(self_at(0), [Dead, Gone])).

%% Its own signal is the thing it chose, not information.
a_drone_does_not_hear_itself_test() ->
    Me = (self_at(0))#drone{signal = [999, 999, 999, 999]},
    ?assertEqual(radio:silence(), radio:heard(Me, [Me])).

%%==============================================================================
%% The ablation
%%==============================================================================

%% ⚠ THE MUTE IS THE INSTRUMENT AND THE BANKS SEPARATE FOR A REASON: muting comms
%% must not also mute cueing, or `drones coordinating' and `drones being cued'
%% would stop being separable findings.
muting_air_leaves_the_ground_bank_alone_test() ->
    Ds = [d(a, attacker, 10, [100, 0, 0, 0]), d(b, defender, 10, [200, 0, 0, 0])],
    ?assertEqual(radio:silence(), radio:heard(self_at(0), Ds, air)),
    ?assertEqual(radio:silence(), radio:heard(self_at(0), Ds, all)),
    %% Ground is already zero, so muting it changes nothing TODAY. The test says
    %% so out loud, because at item 8 it stops being true and this is where the
    %% reader will look.
    ?assertEqual(radio:heard(self_at(0), Ds), radio:heard(self_at(0), Ds, ground)).

%%==============================================================================
%% Volume
%%==============================================================================

volume_is_what_was_said_test() ->
    ?assertEqual(0, radio:volume(self_at(0))),
    ?assertEqual(6, radio:volume(d(a, attacker, 0, [1, -2, 3, 0]))).
