%% @doc The controller contract, the perception boundary, and the genome.
-module(drone_pilot_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).

%%==============================================================================
%% The contract
%%==============================================================================

the_channel_counts_agree_with_the_design_test() ->
    ?assertEqual(41, drone_pilot:inputs()),
    ?assertEqual(10, drone_pilot:outputs()),
    ?assertEqual(8 + 3 * 7 + 12, drone_senses:channels()).

%% ⚠ THE PERCEPTION BOUNDARY, ASSERTED AS A SHAPE. `act/4` takes the drone, the
%% other drones and what it heard. It does NOT take the arena, so munitions in
%% flight and another drone's exact state are unreachable below that line even by
%% accident. A comment would not survive a refactor.
the_pilot_never_receives_the_arena_test() ->
    Exports = drone_pilot:module_info(exports),
    ?assert(lists:member({act, 4}, Exports)),
    ?assertNot(lists:member({act, 5}, Exports)),
    %% and neither does the sensor block
    ?assert(lists:member({sense, 3}, drone_senses:module_info(exports))).

%%==============================================================================
%% The genome
%%==============================================================================

topology() ->
    {In, Hidden, Out} = drone_genome:topology(),
    [In] ++ Hidden ++ [Out].

zeros() -> {topology(), lists:duplicate(drone_genome:weight_count(topology()), 0)}.

the_weight_count_is_bias_plus_inputs_per_neuron_test() ->
    ?assertEqual(24 * 42 + 10 * 25, drone_genome:weight_count([41, 24, 10])),
    ?assertEqual(1258, drone_genome:weight_count(topology())).

%% ⚠ THE PACKED FORM IS CANONICAL, WHICH IS WHY THERE ARE NO MAPS AND NO FLOATS
%% IN IT. `term_to_binary` is not canonical over maps, so a genome carrying one
%% would hash differently in two processes and the identifier a host publishes
%% would stop identifying the thing that ran.
a_genome_round_trips_and_its_id_is_stable_test() ->
    G = zeros(),
    ?assertEqual({ok, G}, drone_genome:unpack(drone_genome:pack(G))),
    ?assertEqual(drone_genome:id(G), drone_genome:id(G)),
    ?assertEqual(64, byte_size(drone_genome:id(G))).

a_different_genome_has_a_different_id_test() ->
    {L, [_ | Rest]} = zeros(),
    ?assertNotEqual(drone_genome:id(zeros()), drone_genome:id({L, [1 | Rest]})).

unpacking_rubbish_is_an_error_and_not_a_crash_test() ->
    ?assertMatch({error, _}, drone_genome:unpack(<<"not a genome">>)),
    ?assertMatch({error, _}, drone_genome:unpack(term_to_binary(hello))),
    ?assertMatch({error, _}, drone_genome:unpack(not_a_binary)).

%%==============================================================================
%% Validation
%%==============================================================================

a_correct_genome_validates_test() ->
    ?assertEqual(ok, drone_genome:validate(zeros())).

%% ⚠ EVERY ONE OF THESE IS A SILENT FAILURE IF IT IS NOT CAUGHT HERE.
%% `network_evaluator` pads a short input layer without complaining and a short
%% output vector falls back to a null command, so a mismatched genome does not
%% crash: it fights badly and produces a result that looks real, which is the
%% worst outcome available because nobody can tell it from a measurement.
a_wrong_input_width_is_refused_test() ->
    ?assertEqual({error, wrong_input_width},
                 drone_genome:validate({[40, 24, 10], []})).

a_wrong_output_width_is_refused_test() ->
    ?assertEqual({error, wrong_output_width},
                 drone_genome:validate({[41, 24, 9], []})).

a_wrong_weight_count_is_refused_test() ->
    ?assertEqual({error, wrong_weight_count}, drone_genome:validate({topology(), [0]})).

%% The limits are a denial-of-service defence rather than a quality bar: a host
%% runs a stranger's network up to 1200 times per drone per engagement, so the
%% cost of a raid is linear in the weight count.
a_pathological_topology_is_refused_test() ->
    ?assertEqual({error, too_many_weights},
                 drone_genome:validate({[41, 4000, 10], []})).

%% ⚠ REJECTED RATHER THAN CLAMPED. Clipping a stranger's weight into range would
%% change the genome, which changes what actually fought, which means the
%% published identifier no longer names the code that ran.
an_out_of_range_weight_is_refused_rather_than_clamped_test() ->
    {L, [_ | Rest]} = zeros(),
    ?assertEqual({error, weight_out_of_range}, drone_genome:validate({L, [99999 | Rest]})).

a_genome_that_is_not_one_is_refused_test() ->
    ?assertEqual({error, not_a_genome}, drone_genome:validate(hello)),
    ?assertEqual({error, too_few_layers}, drone_genome:validate({[41], []})).

%%==============================================================================
%% The float boundary
%%==============================================================================

%% ⚠ QUANTIZATION IS WHERE CLAMPING IS CORRECT, and validation is where it is
%% not. This is an optimiser proposing its own candidate, so shortening it is a
%% legitimate answer to a proposal.
quantization_round_trips_within_its_resolution_test() ->
    Scale = drone_genome:scale(),
    Ws = [0.0, 1.0, -1.0, 0.5, -7.9, 7.9],
    Back = drone_genome:dequantize(drone_genome:quantize(Ws)),
    [?assert(abs(A - B) =< 1.0 / Scale) || {A, B} <- lists:zip(Ws, Back)].

quantization_clamps_rather_than_wrapping_test() ->
    #{weight_max := Max, weight_min := Min} = drone_genome:limits(),
    ?assertEqual([Max], drone_genome:quantize([1000.0])),
    ?assertEqual([Min], drone_genome:quantize([-1000.0])).

%%==============================================================================
%% Flying one
%%==============================================================================

an_invalid_genome_is_refused_rather_than_padded_test() ->
    ?assertMatch({error, _}, drone_pilot:init({[40, 24, 10], []})).

a_valid_genome_produces_a_command_test() ->
    {ok, P} = drone_pilot:init(zeros()),
    A = arena(),
    [Self | Others] = airspace:drones(A),
    {Intent, _P2} = drone_pilot:act(P, Self, Others, []),
    ?assertMatch(#intent{}, Intent).

%% A network of zero weights outputs tanh(0) = 0 on every channel, so the
%% commanded thrust is zero and neither weapon fires. That is a null controller,
%% which is exactly what a zero genome should be.
a_zero_genome_commands_nothing_test() ->
    {ok, P} = drone_pilot:init(zeros()),
    [Self | Others] = airspace:drones(arena()),
    {Intent, _} = drone_pilot:act(P, Self, Others, []),
    ?assertEqual(0, Intent#intent.thrust_fwd),
    ?assertEqual(0, Intent#intent.yaw_rate),
    ?assertEqual(0, Intent#intent.release),
    ?assertEqual(0, Intent#intent.launch).

%% ⚠ AND THE ENGINE CLAMPS AGAIN ANYWAY. A saturated output means full
%% deflection, and the engine must not trust a caller at all, because a
%% stranger's genome reaches it through this same function.
a_saturated_output_is_full_deflection_and_no_more_test() ->
    #{max_accel := A, max_yaw_rate := R} = airspace:limits(),
    Out = [1.0, 0.0, 0.0, 1.0, 1.0, 1.0] ++ lists:duplicate(4, 0.0),
    I = drone_pilot:commands(Out),
    ?assertEqual(A, I#intent.thrust_fwd),
    ?assertEqual(R, I#intent.yaw_rate),
    ?assertEqual(1, I#intent.release),
    ?assertEqual(1, I#intent.launch).

%% A short vector is a null command rather than a crash. Validation is what makes
%% this unreachable; this is what makes it survivable if validation is ever wrong.
a_short_output_vector_is_a_null_command_test() ->
    ?assertEqual(#intent{}, drone_pilot:commands([0.5, 0.5])).

%% ⚠ THE PROPERTY MEMORY EXISTS FOR. A CfC neuron carries internal state, so the
%% same inputs at two different moments need not produce the same command. Without
%% this a signal could not be held, a contact that left the cone could not be
%% tracked, and leading a target would be unreachable.
the_same_inputs_can_give_different_commands_over_time_test() ->
    {ok, P0} = drone_pilot:init(random_genome(4242)),
    [Self | Others] = airspace:drones(arena()),
    {I1, P1} = drone_pilot:act(P0, Self, Others, []),
    {I2, P2} = drone_pilot:act(P1, Self, Others, []),
    {I3, _P3} = drone_pilot:act(P2, Self, Others, []),
    ?assertNotEqual([I1, I2], [I2, I3]).

%%==============================================================================

arena() ->
    airspace:new([{a, attacker, 500 * ?M, 500 * ?M, 100 * ?M, 0},
                  {b, defender, 540 * ?M, 500 * ?M, 110 * ?M, 128},
                  {c, attacker, 520 * ?M, 480 * ?M, 100 * ?M, 0}]).

%% Seeded rather than drawn, so a failure here is reproducible.
random_genome(Seed) ->
    S0 = rand:seed_s(exsss, {Seed, Seed, Seed}),
    {Ws, _} = lists:foldl(fun draw/2, {[], S0},
                          lists:seq(1, drone_genome:weight_count(topology()))),
    {topology(), drone_genome:quantize(Ws)}.

draw(_N, {Acc, S}) ->
    {R, S1} = rand:uniform_s(S),
    {[(R - 0.5) * 4.0 | Acc], S1}.
