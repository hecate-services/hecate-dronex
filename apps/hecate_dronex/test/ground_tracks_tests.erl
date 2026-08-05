%% @doc Contacts in, confirmed tracks out.
-module(ground_tracks_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).

c(Xm, Ym, Tick) -> ground_sensor:contact(one, Tick, Xm * ?M, Ym * ?M, 100 * ?M, 900).

%% Feed the same position for N consecutive ticks.
held(Xm, Ym, Ticks) ->
    lists:foldl(fun (T, S) -> ground_tracks:advance(S, [c(Xm, Ym, T)], T) end,
                ground_tracks:empty(), lists:seq(1, Ticks)).

%%==============================================================================
%% ⚠ A CONTACT IS NOT A TARGET
%%==============================================================================

one_contact_is_a_track_but_not_a_confirmed_one_test() ->
    S = held(100, 100, 1),
    ?assertEqual(1, ground_tracks:count(S)),
    %% Against a network that invents ghosts, one sighting is not worth saying
    %% out loud. This is the entire difference between a contact and a target.
    ?assertEqual([], ground_tracks:confirmed(S)).

enough_evidence_confirms_it_test() ->
    ?assertEqual([], ground_tracks:confirmed(held(100, 100, ?CONFIRM_EVIDENCE - 1))),
    ?assertEqual(1, length(ground_tracks:confirmed(held(100, 100, ?CONFIRM_EVIDENCE)))).

a_lone_ghost_never_confirms_test() ->
    %% One false alarm at a random place, then nothing. It ages out having said
    %% nothing, which is what the threshold is for.
    S = ground_tracks:advance(ground_tracks:empty(), [c(300, 300, 1)], 1),
    Aged = lists:foldl(fun (T, A) -> ground_tracks:advance(A, [], T) end, S,
                       lists:seq(2, ?TRACK_DROP_TICKS + 2)),
    ?assertEqual([], ground_tracks:confirmed(Aged)),
    ?assertEqual(0, ground_tracks:count(Aged)).

%%==============================================================================
%% Association
%%==============================================================================

contacts_far_apart_are_different_targets_test() ->
    S = ground_tracks:advance(ground_tracks:empty(), [c(100, 100, 1), c(600, 600, 1)], 1),
    ?assertEqual(2, ground_tracks:count(S)).

contacts_inside_the_gate_are_the_same_target_test() ->
    Near = (?TRACK_GATE div ?M) div 2,
    S = ground_tracks:advance(ground_tracks:empty(), [c(100, 100, 1)], 1),
    S2 = ground_tracks:advance(S, [c(100 + Near, 100, 2)], 2),
    ?assertEqual(1, ground_tracks:count(S2)).

%% ⚠ A REAL LIMITATION OF A REAL ALGORITHM, ASSERTED RATHER THAN HIDDEN.
two_targets_closer_than_the_gate_merge_test() ->
    Tight = (?TRACK_GATE div ?M) div 3,
    S = ground_tracks:advance(ground_tracks:empty(), [c(100, 100, 1), c(100 + Tight, 100, 1)], 1),
    %% Nearest-neighbour with a gate cannot separate these, and that is why
    %% flying a tight formation through a network is a tactic rather than a
    %% mistake. Multi-hypothesis tracking is not phase 1.
    ?assertEqual(1, ground_tracks:count(S)).

%%==============================================================================
%% ⚠ PREDICTION, WHICH IS WHAT MAKES THE GATE MEANINGFUL
%%==============================================================================

a_fast_mover_stays_one_track_test() ->
    %% Steps of 20 m per tick, which is well inside the gate but adds up fast.
    Step = 20,
    S = lists:foldl(fun (T, A) -> ground_tracks:advance(A, [c(100 + T * Step, 100, T)], T) end,
                    ground_tracks:empty(), lists:seq(1, 12)),
    %% Comparing a contact against where a target WAS rather than where it should
    %% be by now would spawn a new track every few ticks, nothing would ever
    %% reach the threshold, and the network would be blind to exactly the targets
    %% worth seeing.
    ?assertEqual(1, ground_tracks:count(S)),
    ?assertEqual(1, length(ground_tracks:confirmed(S))).

a_track_carries_a_velocity_test() ->
    S = lists:foldl(fun (T, A) -> ground_tracks:advance(A, [c(100 + T * 20, 100, T)], T) end,
                    ground_tracks:empty(), lists:seq(1, 12)),
    [#{vx := Vx, vy := Vy}] = ground_tracks:confirmed(S),
    ?assert(Vx > 0),
    ?assertEqual(0, Vy).

the_position_is_smoothed_not_replaced_test() ->
    S = ground_tracks:advance(ground_tracks:empty(), [c(100, 100, 1)], 1),
    S2 = ground_tracks:advance(S, [c(120, 100, 2)], 2),
    [#{x := X}] = S2,
    %% Half-way. Jumping to a raw contact would make a confirmed track jitter as
    %% badly as the sensor does, so the cue would be noise with a threshold in
    %% front of it.
    ?assert(X > 100 * ?M),
    ?assert(X < 120 * ?M).

%%==============================================================================
%% Ageing
%%==============================================================================

a_target_that_stops_being_seen_is_dropped_test() ->
    S = held(100, 100, ?CONFIRM_EVIDENCE + 2),
    Last = ?CONFIRM_EVIDENCE + 2,
    Aged = lists:foldl(fun (T, A) -> ground_tracks:advance(A, [], T) end, S,
                       lists:seq(Last + 1, Last + ?TRACK_DROP_TICKS + 1)),
    ?assertEqual(0, ground_tracks:count(Aged)).

it_survives_a_gap_shorter_than_the_drop_test() ->
    S = held(100, 100, ?CONFIRM_EVIDENCE + 2),
    Last = ?CONFIRM_EVIDENCE + 2,
    Aged = lists:foldl(fun (T, A) -> ground_tracks:advance(A, [], T) end, S,
                       lists:seq(Last + 1, Last + ?TRACK_DROP_TICKS - 1)),
    ?assertEqual(1, ground_tracks:count(Aged)),
    %% ⚠ AND IT IS STILL CONFIRMED. Demoting on a missed tick would stop the
    %% network cueing precisely when a target is hardest to see, which is when
    %% the cue is worth most.
    ?assertEqual(1, length(ground_tracks:confirmed(Aged))).

%% ⚠ ORDER: ASSOCIATE, THEN AGE.
a_contact_arriving_on_the_drop_tick_saves_the_track_test() ->
    S = ground_tracks:advance(ground_tracks:empty(), [c(100, 100, 1)], 1),
    Due = 1 + ?TRACK_DROP_TICKS,
    Saved = ground_tracks:advance(S, [c(100, 100, Due)], Due),
    %% Ageing first would drop this track on the very tick a contact arrived for
    %% it, so a target at the fringe of a network — seen, lost, seen — would
    %% never accumulate anything and the outer ring would be worth nothing.
    ?assertEqual(1, ground_tracks:count(Saved)).

%%==============================================================================
%% House rules
%%==============================================================================

status_is_bit_flags_on_an_integer_test() ->
    [T] = held(100, 100, 1),
    ?assert(is_integer(maps:get(status, T))),
    [C] = ground_tracks:confirmed(held(100, 100, ?CONFIRM_EVIDENCE)),
    %% Tentative is not cleared when confirmed is set: the track was tentative
    %% and now is also confirmed, which is what a flag field is for.
    ?assertEqual(3, maps:get(status, C)).

it_is_a_pure_fold_with_no_clock_in_it_test() ->
    %% Same contacts, same ticks, same answer — twice, with the wall clock moving
    %% underneath. A fight is 1200 of these and must replay identically on the
    %% island that flew into it.
    ?assertEqual(held(100, 100, 20), held(100, 100, 20)).
