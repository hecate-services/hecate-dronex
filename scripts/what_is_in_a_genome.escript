#!/usr/bin/env escript
%%! -sname dronex_genome_shape
%%
%% What is actually inside the genomes the fleet is breeding?
%%
%% THIS EXISTS BECAUSE THE ROSTER IS THE ONE THING THAT SURVIVES EVERYTHING AND
%% NOTHING EVER LOOKS INSIDE IT. Depth is published, generation is published,
%% exam scores are published. The 1282 numbers a drone actually consists of are
%% carried across raids, persisted through rolls, and never once read.
%%
%% ⚠ IT DESCRIBES, IT DOES NOT GRADE. Nothing here is a fitness, nothing here is
%% tuned on, and a genome is not better for having a wider spread. `CHARTER.md`
%% rule 3: a constant is never set to whichever value produced a number somebody
%% liked, and that applies doubly to numbers this suggestive.
%%
%% ⚠⚠ EVERY TABLE HERE IS MEANINGLESS WITHOUT THE SEEDED CONTROL, and the first
%% version of this script did not have one. `breed:random/1' draws every gene
%% uniform on plus or minus 8192, which is a QUARTER of the 16-bit range, so a
%% freshly seeded genome already has weights spread over [-2, 2] and time
%% constants confined to about [0.406, 0.644]. Read without that, a champion
%% whose weights span [-2.8, 2.6] looks like a wide search and a population with
%% no fast or slow neurons looks like convergence. Both readings are wrong. The
%% control rows are printed FIRST, above the fleet, so they cannot be skipped.
%%
%% ⚠⚠⚠ AND MARGINAL STATISTICS CANNOT TELL A TRAINED NETWORK FROM A RANDOM ONE.
%% Selection acts on the ARRANGEMENT of weights and barely touches their
%% histogram, so "the weights look seeded" is NOT evidence that breeding has done
%% nothing. The tau row is the one that carries structural weight here, because a
%% bound is a bound whatever the arrangement.
%%
%% Usage:
%%   ERL_LIBS=_build/default/lib scripts/what_is_in_a_genome.escript champions
%%   ERL_LIBS=_build/default/lib scripts/what_is_in_a_genome.escript /path/to/dir

main([Dir]) -> report(Dir);
main(_Args) -> report("champions").

report(Dir) ->
    Cs = controls() ++ champions(Dir),
    Layers = drone_genome:layers(),
    io:format("~nWhat is in the genomes, from ~s~n~n", [Dir]),
    io:format("  topology     ~p, so ~p weights and ~p time constants~n",
              [Layers, drone_genome:weight_count(Layers), drone_genome:tau_count(Layers)]),
    io:format("  quantisation Q12, ~p is 1.0, so a gene spans about -8 to 8~n~n",
              [drone_genome:scale()]),
    weights(Cs),
    taus(Cs),
    saturation(Cs),
    kinship(Cs),
    ok.

champions(Dir) ->
    {ok, Files} = file:list_dir(Dir),
    [champion(Dir, F) || F <- lists:sort(Files), lists:suffix(".b64", F)].

%% Two of them, and fixed seeds, so the control is reproducible and so the
%% kinship table has a row for the distance between two genomes that are
%% CERTAIN to be unrelated. That number is the yardstick every other cell in
%% that table is read against.
controls() ->
    [{"SEED-a", element(1, breed:random(rand:seed_s(exsss, {1, 2, 3})))},
     {"SEED-b", element(1, breed:random(rand:seed_s(exsss, {4, 5, 6})))}].

champion(Dir, File) ->
    {ok, B64} = file:read_file(filename:join(Dir, File)),
    {ok, Genome} = drone_genome:unpack(base64:decode(string:trim(B64))),
    {filename:basename(File, ".b64"), Genome}.

split(Genome) ->
    {Layers, Genes} = Genome,
    drone_genome:split(Layers, Genes).

%%------------------------------------------------------------------------------
%% The weights
%%------------------------------------------------------------------------------

weights(Cs) ->
    io:format("  THE WEIGHTS, dequantised~n~n"),
    io:format("  ~-8s ~8s ~8s ~8s ~8s ~8s ~8s~n",
              ["island", "min", "median", "max", "mean|w|", "at rail", "near 0"]),
    [weight_row(N, G) || {N, G} <- Cs],
    io:format("~n  A gene at the rail is one quantised to the 16-bit floor or ceiling,~n"
              "  where mutation can still push but the value cannot move. Near zero~n"
              "  is |w| below 0.01, a synapse that is present and carries nothing.~n~n").

weight_row(Name, Genome) ->
    {W, _T} = split(Genome),
    Ws = drone_genome:dequantize(W),
    Sorted = lists:sort(Ws),
    N = length(Ws),
    Rail = length([Q || Q <- W, Q =:= -32768 orelse Q =:= 32767]),
    Zero = length([X || X <- Ws, abs(X) < 0.01]),
    io:format("  ~-8s ~8.3f ~8.3f ~8.3f ~8.3f ~6b~2s ~6b~2s~n",
              [Name, hd(Sorted), lists:nth(N div 2, Sorted), lists:last(Sorted),
               lists:sum([abs(X) || X <- Ws]) / N, Rail, "", Zero, ""]).

%%------------------------------------------------------------------------------
%% The time constants
%%------------------------------------------------------------------------------

taus(Cs) ->
    io:format("  THE TIME CONSTANTS, one per hidden neuron, on [0.05, 1.0)~n~n"),
    io:format("  ~-8s ~8s ~8s ~8s ~10s ~10s~n",
              ["island", "min", "median", "max", "fast<0.2", "slow>0.8"]),
    [tau_row(N, G) || {N, G} <- Cs],
    io:format("~n  Tau is how long a hidden neuron holds what it saw. Low is a~n"
              "  reflex, high is a memory. A population all at one end has~n"
              "  settled on one way of using time.~n~n").

tau_row(Name, Genome) ->
    {_W, T} = split(Genome),
    Ts = lists:sort([drone_genome:to_tau(Q) || Q <- T]),
    io:format("  ~-8s ~8.3f ~8.3f ~8.3f ~10b ~10b~n",
              [Name, hd(Ts), lists:nth(max(1, length(Ts) div 2), Ts), lists:last(Ts),
               length([X || X <- Ts, X < 0.2]), length([X || X <- Ts, X > 0.8])]).

%%------------------------------------------------------------------------------
%% What the network does with them
%%------------------------------------------------------------------------------

%% ⚠ THIS IS WHERE THE WEIGHTS STOP BEING A HISTOGRAM AND START BEING A
%% CONTROLLER. Ten tanh outputs: three thrusts, a yaw rate, two weapons, four
%% comms channels, and `drone_pilot:commands/1` thresholds them at zero. An
%% output pinned at the rail is a decision the network has stopped making.
saturation(Cs) ->
    io:format("  WHAT THE OUTPUTS DO, over 200 closed-form ticks~n~n"),
    io:format("  ~-8s ~12s ~12s ~10s~n", ["island", "|out|>0.99", "|out|>0.999", "mean |out|"]),
    [sat_row(N, G) || {N, G} <- Cs],
    io:format("~n  These are tanh outputs, so the rail is asymptotic and reaching~n"
              "  it means a large weighted sum, not a clipped one.~n~n").

sat_row(Name, Genome) ->
    Outs = lists:flatten(trace(Genome)),
    N = length(Outs),
    io:format("  ~-8s ~11.1f% ~11.1f% ~10.3f~n",
              [Name,
               100 * length([X || X <- Outs, abs(X) > 0.99]) / N,
               100 * length([X || X <- Outs, abs(X) > 0.999]) / N,
               lists:sum([abs(X) || X <- Outs]) / N]).

trace(Genome) ->
    {ok, #{net := Net}} = drone_pilot:init(Genome),
    fly(Net, 200, 1, []).

fly(_Net, Ticks, N, Acc) when N > Ticks -> lists:reverse(Acc);
fly(Net, Ticks, N, Acc) ->
    {Out, Stepped} = drone_pilot:decide(Net, inputs(N)),
    fly(Stepped, Ticks, N + 1, [Out | Acc]).

inputs(N) ->
    C = drone_senses:channels(),
    [math:sin(N * 0.37 + I * 0.11) * math:cos(N * 0.013 + I * 0.29)
     || I <- lists:seq(1, C)].

%%------------------------------------------------------------------------------
%% Are the islands one population or five?
%%------------------------------------------------------------------------------

%% Raids move genomes between islands, so the archipelago could be converging on
%% one lineage or holding five apart. Mean absolute gene difference says which,
%% and it is the cheapest question here that the raid protocol exists to answer.
kinship(Cs) ->
    io:format("  HOW RELATED ARE THE FIVE, mean |gene difference| in weight units~n~n"),
    Names = [N || {N, _G} <- Cs],
    io:format("  ~-8s~s~n", ["", lists:flatten([io_lib:format("~9s", [N]) || N <- Names])]),
    [kin_row(A, Cs) || A <- Cs],
    io:format("~n  Genes are position-matched: the topology is fixed and shared, so~n"
              "  gene 700 means the same synapse on every island. Zero would be one~n"
              "  genome in five places. The scale to read it against is the mean~n"
              "  |w| column above, which is the distance from a genome to silence.~n~n").

kin_row({NameA, GA}, Cs) ->
    Cells = [io_lib:format("~9.3f", [distance(GA, GB)]) || {_NB, GB} <- Cs],
    io:format("  ~-8s~s~n", [NameA, lists:flatten(Cells)]).

distance({_LA, GenesA}, {_LB, GenesB}) ->
    Pairs = lists:zip(GenesA, GenesB),
    lists:sum([abs(A - B) || {A, B} <- Pairs]) / (length(Pairs) * drone_genome:scale()).
