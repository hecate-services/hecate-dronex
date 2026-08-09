%% @doc Where an engagement begins when neither side can see the other yet.
%% PURE and DETERMINISTIC.
%%
%% THIS EXISTS SO FINDING THE ENEMY IS SOMETHING A DRONE CAN BE GOOD OR BAD AT.
%%
%% ==========================================================================
%% ⚠ WHAT `drone_starts' TURNED OUT TO HAND OUT FOR FREE
%% ==========================================================================
%%
%% The frozen set puts two sides 400 m apart and its own comment justifies that
%% as "inside sensor range, outside the unguided weapon's useful reach, and far
%% enough that closing is a decision rather than a formality". The first two
%% clauses are true. The third is not, and the reason is a weapon the comment
%% does not mention.
%%
%% The sensor reaches 600 m and the GUIDED INTERCEPTOR also reaches 600 m. At
%% 400 m every engagement therefore begins with both sides already seen and both
%% sides already able to shoot. Measured on the live exhibit on 2026-08-09, six
%% recordings out of six: **a munition is in the air at frame zero, every time.**
%% Those fights ran 58 to 192 ticks against the 114 ticks two swarms need to
%% close head on, so about half of them were decided before the sides could have
%% met at all.
%%
%% So the frozen set avoids one free strategy, firing straight ahead with the
%% unguided weapon, and hands out another: launch a guided one immediately at a
%% target that cannot be missed because it was never hidden.
%%
%% ==========================================================================
%% ⚠⚠ 800 m, WHICH IS BEYOND BOTH
%% ==========================================================================
%%
%% 400 m from the centre, so two sides start about 800 m apart in a 1000 m
%% arena. Neither can see the other and neither can reach the other, so the
%% opening of a fight is a search rather than an exchange. A side must close
%% 200 m before anything is visible, and where to close TOWARD is not given.
%%
%% ⚠⚠⚠ AND THIS IS WHY THE RADIO MAY HAVE READ AS NOTHING. `CHARTER.md` says the
%% 120 degree blind arc is "what gives the comms channel something to be FOR",
%% and the ablation's whole job is to say whether the channel is worth anything.
%% It has never once gone clearly positive, and its deltas disagree in sign
%% across islands. A geometry where every contact is visible to everybody from
%% the first tick leaves very little for a drone to tell another drone. That is a
%% candidate explanation, not a finding, and this set is what makes it testable.
%%
%% ==========================================================================
%% ⚠⚠⚠⚠ IT IS NOT FROZEN YET, AND NOTHING MAY BE BRED AGAINST IT UNTIL IT IS
%% MEASURED
%% ==========================================================================
%%
%% `REGISTER D.4' is the precedent and it is not optional: the first drill ladder
%% was written in an order that turned out to be backwards, and only pointing
%% known controllers at it revealed that. The specific risk here is the opposite
%% of the one it replaces. If controllers cannot find each other at all, every
%% engagement runs to the battery and the set produces draws instead of results,
%% which is a different way of measuring nothing.
%%
%% So this must be shown to produce DECIDED fights, with the first weapon fired
%% later than frame zero, before anything sits it. `distant_starts_tests' carries
%% the structural checks; the behavioural sweep is
%% `scripts/what_does_a_distant_start_look_like.escript'.
%%
%% Once something has been bred against it, it freezes and a further set is added
%% beside it. That is the rule `drone_starts' carries and the reason that one was
%% not simply edited.
-module(distant_starts).

-export([count/0, place/3, radius/0, altitudes/0]).

%% The same 48 geometries, so a profile over this set has the same resolution as
%% one over the frozen set and the two are read the same way.
-define(COUNT, 48).

%% ⚠ 400 m FROM THE CENTRE, SO 800 m APART, AND BOTH NUMBERS MATTER. The sensor
%% and the interceptor both reach 600 m, so 800 m is outside both with 200 m to
%% spare. The arena is 1000 m square and the centre is at 500, so a side sits at
%% 100 or 900 and the whole configuration stays inside the walls, which kill.
-define(RADIUS, 8192000).

%% Five altitude bands from 60 to 180 m, unchanged: vertical geometry is
%% exercised rather than every engagement happening on one plane.
-define(BASE_Z, 1228800).
-define(BAND_Z, 614400).
-define(BANDS, 5).

%% How far apart drones of one side are spread along their arc. Unchanged, so
%% the difference between the two sets is separation and nothing else.
-define(SPREAD, 10).

-spec count() -> pos_integer().
count() -> ?COUNT.

-spec radius() -> pos_integer().
radius() -> ?RADIUS.

-spec altitudes() -> [pos_integer()].
altitudes() -> [?BASE_Z + N * ?BAND_Z || N <- lists:seq(0, ?BANDS - 1)].

%% @doc Place `N' attackers and `M' defenders for start `Index'.
%%
%% Same shape as `drone_starts:place/3', deliberately: ids are `{attacker, K}'
%% and `{defender, K}', the configuration rotates with the index, and every
%% heading carries an offset so nobody starts pointed exactly at anybody.
-spec place(pos_integer(), pos_integer(), non_neg_integer()) -> [tuple()].
place(N, M, Index) when N > 0, M > 0 ->
    I = Index rem ?COUNT,
    Base = (I * 256) div ?COUNT,
    Z = lists:nth((I rem ?BANDS) + 1, altitudes()),
    side(attacker, N, Base, Z, I) ++ side(defender, M, Base + 128, Z, I).

side(Side, N, Base, Z, I) ->
    [one(Side, K, fixed:wrap(Base + centred(K, N)), Z, I) || K <- lists:seq(1, N)].

centred(K, N) -> (K - 1) * ?SPREAD - ((N - 1) * ?SPREAD) div 2.

one(Side, K, Angle, Z, I) ->
    {{Side, K},
     Side,
     centre_x() + ?RADIUS * fixed:cos(Angle) div 32768,
     centre_y() + ?RADIUS * fixed:sin(Angle) div 32768,
     Z,
     fixed:wrap(Angle + 128 + offset(I, K))}.

%% ⚠ NEVER LESS THAN 8 UNITS, WHICH IS ABOUT 11 DEGREES, AND IT MATTERS MORE HERE
%% THAN IT DID THERE. On the frozen set the offset stops a drone being
%% bore-sighted at turn one. Here it also decides whether a side flying straight
%% ahead arrives anywhere near the other one, which is the difference between a
%% search and a corridor.
offset(I, K) -> 8 + ((I * 5 + K * 3) rem 24).

centre_x() ->
    #{arena_x := X} = airspace:limits(),
    X div 2.

centre_y() ->
    #{arena_y := Y} = airspace:limits(),
    Y div 2.
