%% @doc The two gene blocks are on different scales, and the operators know it.
%%
%% THESE EXIST BECAUSE THE FLEET RAN 150 GENERATIONS WITHOUT EVER PRODUCING A
%% FAST OR SLOW NEURON. Not one of 10,848 time constants across five rosters was
%% below 0.2 or above 0.8, while every entry on every island carried weights
%% outside the seeding box. One operator, one rate, opposite outcomes, because a
%% gene unit is worth four times as much to a tau as to a weight and both the
%% draw and the step were quoted in gene units.
%%
%% ⚠ EVERY TEST HERE WAS RUN AGAINST THE OLD CODE AND SEEN TO FAIL. A test that
%% has only ever been green cannot tell you it is testing anything.
-module(breed_scale_tests).

-include_lib("eunit/include/eunit.hrl").

seeded(N) -> rand:seed_s(exsss, {N, N + 1, N + 2}).

taus_of(Genome) ->
    {Layers, Genes} = Genome,
    {_W, T} = drone_genome:split(Layers, Genes),
    [drone_genome:to_tau(Q) || Q <- T].

weights_of(Genome) ->
    {Layers, Genes} = Genome,
    {W, _T} = drone_genome:split(Layers, Genes),
    drone_genome:dequantize(W).

many_taus(N) ->
    lists:flatten(element(1, lists:foldl(fun(_I, {Acc, S}) ->
                                             {G, S1} = breed:random(S),
                                             {[taus_of(G) | Acc], S1}
                                         end, {[], seeded(1)}, lists:seq(1, N)))).

%% The one that matters: seeding must be able to draw a reflex and a memory.
%%
%% Fails on the old code by construction, not by luck. The old draw was
%% plus or minus 8192, which to_tau maps onto [0.406, 0.644], so no number of
%% samples could ever produce either end.
seeding_can_draw_a_fast_neuron_test() ->
    Ts = many_taus(40),
    ?assert(length([X || X <- Ts, X < 0.2]) > 0).

seeding_can_draw_a_slow_neuron_test() ->
    Ts = many_taus(40),
    ?assert(length([X || X <- Ts, X > 0.8]) > 0).

%% And it must cover the range broadly, not merely touch the ends. A draw that
%% produced 0.05 and 0.99 and nothing between would pass the two above.
seeding_spreads_taus_across_the_whole_range_test() ->
    Ts = many_taus(40),
    Deciles = lists:usort([trunc((X - 0.05) / 0.95 * 10) || X <- Ts]),
    ?assert(length(Deciles) >= 9).

%% Weights keep the range they had. This is the control: the fix must not have
%% widened the weight draw while widening the tau draw.
seeding_leaves_the_weight_draw_alone_test() ->
    {G, _S} = breed:random(seeded(7)),
    Ws = weights_of(G),
    ?assert(lists:max(Ws) =< 2.0),
    ?assert(lists:min(Ws) >= -2.0),
    %% and it does use most of that range, so this is not passing on a narrow draw
    ?assert(lists:max(Ws) > 1.9),
    ?assert(lists:min(Ws) < -1.9).

%% A seeded gene must never exceed the encodable ceiling. At the old draw width
%% this was unreachable; at full width, round/1 can land on 32768 and the
%% ceiling is 32767.
seeding_never_exceeds_the_gene_ceiling_test() ->
    #{weight_min := Lo, weight_max := Hi} = drone_genome:limits(),
    Genes = lists:flatten([begin
                               {{_L, Gs}, _} = breed:random(seeded(I)),
                               Gs
                           end || I <- lists:seq(1, 30)]),
    ?assertEqual([], [G || G <- Genes, G < Lo orelse G > Hi]).

%% The step is scaled by the same ratio as the draw, so one nudge is the same
%% fraction of a tau's range as of a weight's.
tau_sigma_is_scaled_by_the_ratio_of_the_draws_test() ->
    ?assertEqual(breed:sigma() * 4, breed:tau_sigma()).

%% ⚠ THE BEHAVIOURAL FORM OF THE SAME THING, because a constant can agree with
%% another constant while the operator ignores both. Mutating a genome whose
%% taus all sit mid-range must move them measurably further, in gene units, than
%% it moves the weights.
mutation_moves_taus_faster_than_weights_in_gene_units_test() ->
    {G, S} = breed:random(seeded(21)),
    {Layers, Genes} = G,
    Moved = lists:foldl(fun(_I, {Acc, St}) ->
                            breed:mutate(Acc, St, breed:sigma())
                        end, {G, S}, lists:seq(1, 200)),
    {{Layers, After}, _} = Moved,
    {W0, T0} = drone_genome:split(Layers, Genes),
    {W1, T1} = drone_genome:split(Layers, After),
    ?assert(mean_abs_delta(T0, T1) > 2.0 * mean_abs_delta(W0, W1)).

mean_abs_delta(A, B) ->
    Ds = [abs(X - Y) || {X, Y} <- lists:zip(A, B)],
    lists:sum(Ds) / length(Ds).

%% Drift must actually reach the ends of the range in a plausible number of
%% generations. The population measurement said it needed about 11,000; this
%% asserts a genome seeded mid-band can leave the old band inside 200.
mutation_can_leave_the_old_seeding_band_test() ->
    {G, S} = breed:random(seeded(31)),
    {Moved, _} = lists:foldl(fun(_I, {Acc, St}) ->
                                 breed:mutate(Acc, St, breed:sigma())
                             end, {G, S}, lists:seq(1, 200)),
    Ts = taus_of(Moved),
    Outside = [X || X <- Ts, X < 0.406 orelse X > 0.644],
    ?assert(length(Outside) > 0).
