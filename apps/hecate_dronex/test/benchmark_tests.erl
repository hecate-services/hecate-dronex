%% @doc The frozen exam, the start set and the drills.
-module(benchmark_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

null_genome() ->
    {topology(), lists:duplicate(drone_genome:gene_count(topology()), 0)}.

%%==============================================================================
%% The start set
%%==============================================================================

every_start_places_everybody_inside_the_arena_test() ->
    #{arena_x := X, arena_y := Y, arena_z := Z} = airspace:limits(),
    [begin
         ?assert(Px > 0 andalso Px < X),
         ?assert(Py > 0 andalso Py < Y),
         ?assert(Pz > 0 andalso Pz < Z)
     end
     || I <- lists:seq(0, drone_starts:count() - 1),
        {_Id, _S, Px, Py, Pz, _Yaw} <- drone_starts:place(3, 3, I)].

%% ⚠ THE LESSON THE SIBLING MEASURED, ASSERTED HERE. Under an all-mutually-facing
%% generator its floor bot against its own clone drew 106 of 160 matches with 70
%% percent hitting the turn cap. Facing two swarms exactly at each other
%% manufactures stalemates, and it also hands out "fire straight ahead at turn
%% one" for free.
nobody_starts_bore_sighted_test() ->
    [?assert(offset_from_inward(Start) >= 8)
     || I <- lists:seq(0, drone_starts:count() - 1),
        Start <- drone_starts:place(2, 2, I)].

%% How far a drone's heading is from pointing exactly at the arena centre.
offset_from_inward({_Id, _S, X, Y, _Z, Yaw}) ->
    #{arena_x := Ax, arena_y := Ay} = airspace:limits(),
    Dx = Ax div 2 - X,
    Dy = Ay div 2 - Y,
    R = fixed:mag3(Dx, Dy, 0),
    %% along/5 is the cosine of the angle between the nose and the centre. An
    %% 8 unit offset is about 11 degrees, whose cosine is about 0.98.
    angle_units(fixed:along(Dx, Dy, 0, R, Yaw)).

angle_units(Cos) -> length([A || A <- lists:seq(0, 64), fixed:cos(A) > Cos]).

ids_are_unique_within_a_start_test() ->
    [begin
         Ids = [Id || {Id, _S, _X, _Y, _Z, _Yaw} <- drone_starts:place(4, 4, I)],
         ?assertEqual(length(Ids), length(lists:usort(Ids)))
     end || I <- lists:seq(0, drone_starts:count() - 1)].

the_set_is_a_pure_function_of_its_index_test() ->
    ?assertEqual(drone_starts:place(2, 3, 7), drone_starts:place(2, 3, 7)),
    ?assertNotEqual(drone_starts:place(2, 3, 7), drone_starts:place(2, 3, 8)).

the_index_wraps_rather_than_failing_test() ->
    N = drone_starts:count(),
    ?assertEqual(drone_starts:place(1, 1, 0), drone_starts:place(1, 1, N)).

%% Altitude is varied across the set, so vertical geometry is exercised rather
%% than every engagement happening on one plane.
the_set_spans_several_altitudes_test() ->
    Zs = [Z || I <- lists:seq(0, drone_starts:count() - 1),
               {_Id, _S, _X, _Y, Z, _Yaw} <- drone_starts:place(1, 1, I)],
    ?assertEqual(5, length(lists:usort(Zs))).

%%==============================================================================
%% The drills
%%==============================================================================

%% ⚠ THE ORDER IS MEASURED, NOT ASSERTED, AND IT IS FROZEN. Register `D.4': the
%% first ladder graded on how a drill MOVED and five of its six rungs turned out
%% to be one rung repeated. This one grades on whether the drill SHOOTS, and its
%% order is the order 48 starts put the rungs in, which is not the order they
%% were guessed in: a stationary shooter is the HARDEST rung, because closing
%% costs aim and it never pays that.
there_are_six_rungs_in_a_fixed_order_test() ->
    ?assertEqual([hoverer, orbiter, evader, chaser, duellist, sniper],
                 drone_drills:kinds()),
    ?assertEqual(drone_drills:kinds(), benchmark:rungs()).

every_rung_describes_itself_test() ->
    [?assert(byte_size(drone_drills:describe(K)) > 0) || K <- drone_drills:kinds()].

%% ⚠ A DRILL READS THE SAME SENSOR VECTOR AN EVOLVED CONTROLLER READS, so it
%% cannot see behind itself or past 600 m. A drill written against the arena
%% would be beating genomes with better eyes, and every benchmark number would be
%% measured against an unfair opponent.
a_drill_is_blind_where_a_pilot_is_blind_test() ->
    ?assertEqual({act, 4}, hd([E || {act, 4} = E <- drone_drills:module_info(exports)])),
    ?assert(lists:member({act, 4}, drone_pilot:module_info(exports))).

the_hoverer_holds_station_test() ->
    #{gravity := G} = airspace:limits(),
    {I, _} = drone_drills:act(drone_drills:init(hoverer), lone(), [], []),
    ?assertEqual(G, I#intent.thrust_vert),
    ?assertEqual(0, I#intent.thrust_fwd),
    ?assertEqual(0, I#intent.release).

%% The drills with a period reverse deterministically from their own counter, so
%% a benchmark needs no clock and no generator.
the_orbiter_weaves_on_a_period_test() ->
    Rates = [thrust_vert_after(orbiter, N) || N <- lists:seq(0, 90)],
    ?assert(lists:max(Rates) > lists:min(Rates)),
    ?assertEqual(Rates, [thrust_vert_after(orbiter, N) || N <- lists:seq(0, 90)]).

thrust_vert_after(Kind, N) ->
    {I, _} = drone_drills:act({Kind, N}, lone(), [], []),
    I#intent.thrust_vert.

%% A drill that sees nothing holds station rather than wandering, so its rung's
%% difficulty does not depend on where it happened to drift.
%% ⚠ THE ARMED RUNGS TURN TOWARD WHAT THEY SEE AND THE EVADER TURNS AWAY, which
%% is the behavioural difference the ladder's two halves rest on.
%% ⚠ THE CONTACT IS OFF THE NOSE ON PURPOSE. Dead ahead, "turn toward" is
%% correctly a no-op and the two drills do NOT mirror each other, which is what
%% the first version of this test tripped over. A behaviour that only shows at an
%% angle has to be tested at an angle.
the_evader_turns_away_and_the_chaser_turns_toward_test() ->
    {E, _} = drone_drills:act(drone_drills:init(evader), lone(), [off_axis()], []),
    {C, _} = drone_drills:act(drone_drills:init(chaser), lone(), [off_axis()], []),
    ?assertNotEqual(0, E#intent.yaw_rate),
    ?assertNotEqual(0, C#intent.yaw_rate),
    ?assertEqual(E#intent.yaw_rate, -C#intent.yaw_rate).

a_drill_with_nothing_in_sight_holds_station_test() ->
    #{gravity := G} = airspace:limits(),
    [begin
         {I, _} = drone_drills:act(drone_drills:init(K), lone(), [], []),
         ?assertEqual(G, I#intent.thrust_vert)
     end || K <- [evader, chaser, sniper, duellist]].

%% ⚠ EXACTLY THE ARMED HALF SHOOTS, AND THAT SPLIT IS THE LADDER. `D.4` measured
%% that whether a drill shoots is the axis that separates controllers and how it
%% moves is not, so three rungs are unarmed and three are armed. If an unarmed
%% rung ever gained a weapon the bottom of the curve would quietly stop being the
%% bottom.
exactly_the_armed_half_shoots_test() ->
    Firing = [K || K <- drone_drills:kinds(), fires(K)],
    ?assertEqual([chaser, duellist, sniper], Firing).

fires(K) ->
    {I, _} = drone_drills:act(drone_drills:init(K), lone(), [close()], []),
    I#intent.release =:= 1 orelse I#intent.launch =:= 1.

lone() ->
    hd(airspace:drones(airspace:new([{a, attacker, 500 * 20480, 500 * 20480,
                                      100 * 20480, 0}]))).

close() ->
    hd(airspace:drones(airspace:new([{b, defender, 505 * 20480, 500 * 20480,
                                      100 * 20480, 0}]))).

off_axis() ->
    hd(airspace:drones(airspace:new([{b, defender, 540 * 20480, 520 * 20480,
                                      100 * 20480, 0}]))).

%%==============================================================================
%% Sitting it
%%==============================================================================

%% ⚠ NO SCORE, NO TOTAL, NO WEIGHTED AVERAGE, and this is the test that keeps it
%% that way. A single number needs weights, weights are a judgement about which
%% rung matters, and a judgement smuggled into an instrument is the thing
%% instruments exist to avoid.
the_profile_is_a_curve_and_never_a_number_test() ->
    {ok, P} = benchmark:sit(null_genome(), #{starts => 2}),
    ?assertEqual([draws, losses, rungs, starts, wins], lists:sort(maps:keys(P))),
    ?assertNot(maps:is_key(score, P)),
    ?assertNot(maps:is_key(total, P)).

%% Names travel with the vector, so a reader never has to mirror the rung order
%% in its own source. A sibling shipped positional lists, appended a field, and
%% the reader's mirror did not follow.
the_rung_names_travel_with_the_numbers_test() ->
    {ok, P} = benchmark:sit(null_genome(), #{starts => 1}),
    #{rungs := R, wins := W, draws := D, losses := L} = P,
    ?assertEqual(length(R), length(W)),
    ?assertEqual(length(R), length(D)),
    ?assertEqual(length(R), length(L)).

every_start_is_accounted_for_test() ->
    {ok, P} = benchmark:sit(null_genome(), #{starts => 4}),
    #{wins := W, draws := D, losses := L, starts := N} = P,
    ?assertEqual(4, N),
    [?assertEqual(N, A + B + C) || {A, B, C} <- lists:zip3(W, D, L)].

%% ⚠ A PARTIAL RUN REPORTS WHAT IT ACTUALLY RAN. Silent truncation reads as
%% complete coverage when it is not.
a_partial_run_says_so_test() ->
    {ok, P} = benchmark:sit(null_genome(), #{starts => 3}),
    ?assertEqual(3, maps:get(starts, P)),
    ?assertNotEqual(benchmark:starts(), maps:get(starts, P)).

an_unsat_profile_is_distinguishable_from_a_lost_one_test() ->
    Empty = benchmark:empty(),
    ?assertEqual(0, maps:get(starts, Empty)),
    {ok, Sat} = benchmark:sit(null_genome(), #{starts => 2}),
    ?assertEqual(2, maps:get(starts, Sat)).

an_invalid_genome_cannot_sit_it_test() ->
    ?assertMatch({error, _}, benchmark:sit({[40, 24, 10], []})).

%% Deterministic: no clock, no generator, so the same genome scores the same
%% profile every time. Without this the benchmark measures the weather.
the_same_genome_scores_the_same_profile_test() ->
    {ok, A} = benchmark:sit(null_genome(), #{starts => 3}),
    {ok, B} = benchmark:sit(null_genome(), #{starts => 3}),
    ?assertEqual(A, B).

%% ⚠ THE ASSUMPTION THAT LETS THE BENCHMARK RUN ONE SEAT INSTEAD OF TWO, made a
%% test rather than left in a comment. `drone_starts:place/3` is symmetric under
%% swapping the sides in a one-against-one, so the second seat would cost twice
%% the time for identical numbers. The day that stops being true, this goes red.
the_two_seats_are_geometrically_symmetric_test() ->
    [begin
         [{_, attacker, Ax, Ay, Az, Ayaw}, {_, defender, Dx, Dy, Dz, Dyaw}] =
             drone_starts:place(1, 1, I),
         #{arena_x := X, arena_y := Y} = airspace:limits(),
         %% Mirrored through the centre in position, and half a turn apart in
         %% heading, up to the per-index offset that differs by construction.
         ?assertEqual(X - Ax, Dx),
         ?assertEqual(Y - Ay, Dy),
         ?assertEqual(Az, Dz),
         ?assert(is_integer(Ayaw) andalso is_integer(Dyaw))
     end || I <- lists:seq(0, drone_starts:count() - 1)].

%% A null controller commands nothing, so it falls out of the sky and loses every
%% rung. That is the floor, and a floor a benchmark can actually reach is what
%% makes the numbers above it mean something.
a_null_controller_loses_everything_test() ->
    {ok, P} = benchmark:sit(null_genome(), #{starts => 4}),
    #{losses := L} = P,
    ?assertEqual(lists:duplicate(6, 4), L).

%% ⚠ THE PROPERTY THE WHOLE INSTRUMENT RESTS ON, and the one that was broken for
%% an afternoon. Register `D.5`: the CfC time constants were drawn from the
%% process-global generator and left out of the genome, so two runs of the same
%% benchmark on the same genome disagreed. A benchmark that is not reproducible
%% is not a benchmark.
the_same_genome_scores_the_same_profile_twice_running_test() ->
    G = seeded_genome(7),
    {ok, A} = benchmark:sit(G, #{starts => 4}),
    {ok, B} = benchmark:sit(G, #{starts => 4}),
    ?assertEqual(A, B).

seeded_genome(Seed) ->
    S0 = rand:seed_s(exsss, {Seed, Seed, Seed}),
    {Ws, _} = lists:foldl(fun (_N, {Acc, S}) ->
                                  {R, S1} = rand:uniform_s(S),
                                  {[(R - 0.5) * 4.0 | Acc], S1}
                          end, {[], S0},
                          lists:seq(1, drone_genome:gene_count(topology()))),
    {topology(), drone_genome:quantize(Ws)}.
