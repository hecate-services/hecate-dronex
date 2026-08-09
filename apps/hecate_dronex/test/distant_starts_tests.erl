%% @doc A start set that begins out of sight.
-module(distant_starts_tests).

-include_lib("eunit/include/eunit.hrl").

metres() -> 20480.

separation(Set, Index) ->
    [{_, _, X1, Y1, Z1, _}, {_, _, X2, Y2, Z2, _}] = Set:place(1, 1, Index),
    fixed:mag3(X2 - X1, Y2 - Y1, Z2 - Z1).

%%==============================================================================
%% ⚠ THE POINT OF THE SET, AND THE ONE THING THE FROZEN SET CANNOT DO
%%==============================================================================

%% ⚠⚠ THE FROZEN SET HANDS OUT A FREE SHOT AND ITS OWN COMMENT DOES NOT SEE IT.
%% `drone_starts' justifies 400 m as "outside the unguided weapon's useful
%% reach", which is true of the 15 m release and says nothing about the GUIDED
%% interceptor, which reaches 600 m. So every engagement there begins with both
%% sides visible AND both sides able to shoot. Measured on the live exhibit on
%% 2026-08-09, six recordings of six: a munition is in the air at frame zero,
%% every time.
nobody_can_see_anybody_at_the_start_test() ->
    Reach = drone_senses:range(),

    [?assert(separation(distant_starts, I) > Reach)
     || I <- lists:seq(0, distant_starts:count() - 1)],

    %% And the frozen set is the opposite, which is why this one exists. Stated
    %% here rather than assumed, so the day the frozen set changes this fails
    %% loudly instead of quietly measuring the same thing twice.
    [?assert(separation(drone_starts, I) =< Reach)
     || I <- lists:seq(0, drone_starts:count() - 1)].

%% ⚠ AND THE GUIDED WEAPON CANNOT REACH EITHER, which is the half the frozen
%% set's reasoning missed. The interceptor's range is the same 600 m as the
%% sensor, so one number covers both.
the_guided_weapon_cannot_reach_at_the_start_test() ->
    #{lock_range := Lock} = airspace:limits(),
    [?assert(separation(distant_starts, I) > Lock)
     || I <- lists:seq(0, distant_starts:count() - 1)].

%% ⚠⚠⚠ EVERYTHING STAYS INSIDE THE WALLS, WHICH KILL. `REGISTER D.1': the arena's
%% walls kill a drone flying flat out, so a start set that placed anybody outside
%% or hard against them would be scoring the geometry rather than the controller.
%% 400 m from a centre at 500 m leaves 100 m of margin on every side.
every_placement_is_inside_the_arena_test() ->
    #{arena_x := AX, arena_y := AY, arena_z := AZ} = airspace:limits(),

    [begin
         ?assert(X > 0 andalso X < AX),
         ?assert(Y > 0 andalso Y < AY),
         ?assert(Z > 0 andalso Z < AZ)
     end
     || I <- lists:seq(0, distant_starts:count() - 1),
        {_Id, _Side, X, Y, Z, _Yaw} <- distant_starts:place(3, 3, I)].

%%==============================================================================
%% The properties it shares with the frozen set, deliberately
%%==============================================================================

%% The separation is the ONLY difference. Same count, same altitude bands, same
%% spread, same id shape: a profile over this set is read the same way as one
%% over the frozen set, and a difference between the two is about distance.
it_differs_from_the_frozen_set_in_separation_and_nothing_else_test() ->
    ?assertEqual(drone_starts:count(), distant_starts:count()),
    ?assertEqual(drone_starts:altitudes(), distant_starts:altitudes()),
    ?assertEqual(2 * distant_starts:radius(), 2 * 2 * drone_starts:radius()),
    ?assertEqual(800, 2 * distant_starts:radius() div metres()).

%% ⚠ NOBODY STARTS POINTED EXACTLY AT ANYBODY, and it matters more here than it
%% did on the frozen set. There the offset stops a drone being bore-sighted at
%% turn one; here it also decides whether a side flying straight ahead arrives
%% anywhere near the other one, which is the difference between a search and a
%% corridor.
nobody_starts_bore_sighted_test() ->
    [begin
         [{_, _, X1, Y1, _, Yaw1}, {_, _, X2, Y2, _, _}] = distant_starts:place(1, 1, I),
         R = fixed:mag3(X2 - X1, Y2 - Y1, 0),
         %% The cosine between the nose and the line of sight. Exactly 1 would be
         %% pointed straight at them.
         Along = fixed:along(X2 - X1, Y2 - Y1, 0, R, Yaw1),
         ?assert(Along < 32768)
     end || I <- lists:seq(0, distant_starts:count() - 1)].

ids_are_unique_so_two_entrants_never_become_one_test() ->
    Placed = distant_starts:place(3, 3, 7),
    Ids = [Id || {Id, _S, _X, _Y, _Z, _Yaw} <- Placed],
    ?assertEqual(6, length(Ids)),
    ?assertEqual(length(Ids), length(lists:usort(Ids))).

placing_is_deterministic_test() ->
    ?assertEqual(distant_starts:place(2, 2, 11), distant_starts:place(2, 2, 11)),
    ?assertNotEqual(distant_starts:place(2, 2, 11), distant_starts:place(2, 2, 12)).

%% Wrapping the index rather than failing, exactly as the frozen set does, so a
%% caller counting past the end gets a start rather than a crash.
the_index_wraps_test() ->
    ?assertEqual(distant_starts:place(1, 1, 0),
                 distant_starts:place(1, 1, distant_starts:count())).
