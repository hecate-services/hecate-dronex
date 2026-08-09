%% @doc Where an engagement used to begin. PURE and DETERMINISTIC.
%%
%% ==========================================================================
%% ⚠⚠⚠⚠ RETIRED 2026-08-09. NOTHING FLIES THIS ANY MORE. `distant_starts' IS THE
%% SET, AND THIS IS KEPT AS THE CONTROL IN A MEASUREMENT THAT CAN BE RE-RUN
%% ==========================================================================
%%
%% It puts two sides 400 m apart. The sensor reaches 600 m and, until the same
%% day, so did the guided interceptor — so every engagement opened with both
%% sides visible AND both able to shoot, and the comment below justifying 400 m
%% as "outside the unguided weapon's useful reach" was true of the dumb round and
%% silent about the guided one. Six live recordings of six had a munition in the
%% air at frame zero.
%%
%% It is NOT dead code and should not be deleted on that reasoning.
%% `scripts/what_does_a_distant_start_look_like.escript' flies both sets with the
%% same controllers and prints the difference, which is the evidence for the
%% replacement and stops being re-runnable the moment this module goes. The whole
%% sweep is in `measurements/distant_starts_48.txt'.
%%
%% Everything from here down is the original reasoning, kept intact.
%%
%% THIS EXISTS SO TWO ISLANDS AGREE ON WHAT A FIGHT WAS. A start set is not a
%% test fixture: two machines running the same controllers from different
%% starting positions produce results that cannot be compared, so this is part of
%% the contract a raider and a host both submit to, and it travels with a raid
%% request.
%%
%% ==========================================================================
%% ⚠ THE HEADING OFFSET IS THE PART THAT MATTERS, AND IT IS BORROWED RATHER THAN
%% REASONED OUT AGAIN
%% ==========================================================================
%%
%% The sibling line measured this. Under an all-mutually-facing generator its
%% floor bot against its own clone drew 106 of 160 matches, with 70 percent
%% hitting the turn cap; with a per-index heading offset the same 80 geometries
%% gave 67 wins, 67 losses and 26 draws.
%%
%% **Facing two swarms exactly at each other manufactures stalemates.** It also
%% kills a second degeneracy: with at least 8 angle units of offset on every
%% start, nothing is ever bore-sighted at turn one, so "fire straight ahead
%% immediately" is not a strategy the geometry hands out for free.
%%
%% ⚠⚠ AND THE SET IS FROZEN THE DAY THE FIRST POPULATION IS BRED AGAINST IT.
%% CHARTER.md: a benchmark adjusted after training has started measures the
%% adjustment. If this ever needs to change, a NEW set is added beside it with
%% its own name and its own history, and the old one keeps being published.
-module(drone_starts).

-export([count/0, place/3, radius/0, altitudes/0]).

%% 48 geometries. Enough that a win rate has resolution to about two percent,
%% and few enough that a benchmark of six rungs is 288 engagements rather than
%% thousands.
-define(COUNT, 48).

%% 200 m from the centre, so two swarms start about 400 m apart: inside sensor
%% range, outside the unguided weapon's useful reach, and far enough that closing
%% is a decision rather than a formality.
-define(RADIUS, 4096000).

%% Five altitude bands from 60 to 180 m, so vertical geometry is exercised
%% rather than every engagement happening on one plane.
-define(BASE_Z, 1228800).
-define(BAND_Z, 614400).
-define(BANDS, 5).

%% How far apart drones of one side are spread along their arc.
-define(SPREAD, 10).

-spec count() -> pos_integer().
count() -> ?COUNT.

-spec radius() -> pos_integer().
radius() -> ?RADIUS.

-spec altitudes() -> [pos_integer()].
altitudes() -> [?BASE_Z + N * ?BAND_Z || N <- lists:seq(0, ?BANDS - 1)].

%% @doc Place `N' attackers and `M' defenders for start `Index'.
%%
%% Attackers take one arc and defenders the opposite one, both facing roughly
%% inward, with the whole configuration rotated by the index and every heading
%% offset so that nobody starts pointed exactly at anybody.
%%
%% Ids are `{attacker, K}` and `{defender, K}`, which is what makes a result
%% readable without a lookup table and what stops two entrants sharing an id: the
%% arena keys drones by id and two that collided would silently become one.
-spec place(pos_integer(), pos_integer(), non_neg_integer()) -> [tuple()].
place(N, M, Index) when N > 0, M > 0 ->
    I = Index rem ?COUNT,
    Base = (I * 256) div ?COUNT,
    Z = lists:nth((I rem ?BANDS) + 1, altitudes()),
    side(attacker, N, Base, Z, I) ++ side(defender, M, Base + 128, Z, I).

side(Side, N, Base, Z, I) ->
    [one(Side, K, fixed:wrap(Base + centred(K, N)), Z, I) || K <- lists:seq(1, N)].

%% Spread a side evenly about its own arc centre, so adding a drone widens the
%% formation symmetrically instead of shifting the whole side sideways.
centred(K, N) -> (K - 1) * ?SPREAD - ((N - 1) * ?SPREAD) div 2.

one(Side, K, Angle, Z, I) ->
    {{Side, K},
     Side,
     centre_x() + ?RADIUS * fixed:cos(Angle) div 32768,
     centre_y() + ?RADIUS * fixed:sin(Angle) div 32768,
     Z,
     fixed:wrap(Angle + 128 + offset(I, K))}.

%% ⚠ NEVER LESS THAN 8 UNITS, WHICH IS ABOUT 11 DEGREES. That is the whole point:
%% see the module doc. The K term means two drones on the same side do not start
%% on identical headings either.
offset(I, K) -> 8 + ((I * 5 + K * 3) rem 24).

centre_x() ->
    #{arena_x := X} = airspace:limits(),
    X div 2.

centre_y() ->
    #{arena_y := Y} = airspace:limits(),
    Y div 2.
