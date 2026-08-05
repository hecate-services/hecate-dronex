%% @doc A controller on the wire, and the limits a host enforces on one.
%%
%% THIS EXISTS SO A DRONE CAN FIGHT ON A STRANGER'S MACHINE. That is the charter's
%% first line, and every decision below answers to it: a genome has to survive
%% being written down, sent, received by somebody who did not make it, and checked
%% before it is allowed to run.
%%
%% ==========================================================================
%% THE FORMAT
%% ==========================================================================
%%
%%     {Layers, Genes}   Layers :: [pos_integer()], layer widths in order
%%                       Genes  :: [integer()], and it is TWO blocks:
%%                                   weight_count(Layers) weights, bias-then-
%%                                   weights per neuron, neurons in order,
%%                                   layers in order
%%                                 then tau_count(Layers) time constants, one
%%                                   per HIDDEN neuron
%%
%% ==========================================================================
%% ⚠ THE TIME CONSTANTS ARE IN THE GENOME, AND LEAVING THEM OUT WAS A DEFECT
%% ==========================================================================
%%
%% Register `D.5'. `network_evaluator:create_cfc_feedforward/5' draws a per-neuron
%% `tau' from the process-global generator, and `set_weights/2' does NOT touch it:
%% two networks built from the same genome came out with tau 0.625 and 0.359.
%%
%% So the genome did not specify the controller. Three things broke at once: the
%% benchmark was not reproducible, a champion could not be rebuilt from its own
%% genome, and, worst, **a genome sent to another island would fly a different
%% drone there**, which is the one property this whole format exists to provide.
%%
%% Carrying them here fixes all three and makes the time constants EVOLVE, which
%% is what a learnable time constant was supposed to mean. One vector, one
%% mutation operator, and the memory's timescale is selected along with
%% everything else.
%%
%% ⚠ NO FLOATS AND NO MAPS ANYWHERE IN IT. `term_to_binary' is NOT canonical over
%% maps, so a content hash of a genome carrying one is not stable between two
%% processes, and the identifier a host publishes would stop identifying the thing
%% that ran. Over tuples and integer lists it is canonical, so packing is one call.
%%
%% ⚠⚠ THE QUANTIZED FORM IS THE GENOME, NOT A COMPRESSION OF IT. The trainer works
%% in floats; quantization happens at admission to the roster; what is stored,
%% flown, published and exported is the quantized value dequantized back. The
%% alternative, keeping floats and quantizing only for the wire, means the
%% identifier published for a fight names something slightly different from what
%% flew. It also costs four times the bytes.
%%
%% ==========================================================================
%% WHY VALIDATE RATHER THAN CLAMP
%% ==========================================================================
%%
%% Clipping a stranger's weight into range silently changes the genome, which
%% changes what actually fought, which means the published identifier no longer
%% identifies the code that ran. So a foreign genome is REJECTED rather than
%% repaired.
%%
%% THE LIMITS ARE A DENIAL-OF-SERVICE DEFENCE, NOT A QUALITY BAR. A host runs a
%% stranger's network up to 1200 times per drone per engagement, so the cost of a
%% raid is linear in the weight count. Nothing here judges whether a genome is any
%% good; that is what the engagement is for.
-module(drone_genome).

%% The wire
-export([pack/1, unpack/1, id/1]).
%% The contract a host enforces before running anything
-export([validate/1, limits/0, weight_count/1, tau_count/1, gene_count/1, topology/0]).
%% The float boundary
-export([quantize/1, dequantize/1, scale/0, split/2, to_tau/1]).

-export_type([genome/0]).

-type genome() :: {[pos_integer()], [integer()]}.

%% Q12: 4096 is 1.0, so a 16-bit weight spans about minus eight to eight. Wide
%% enough that saturation is rare and narrow enough that two bytes hold a weight.
-define(SCALE, 4096).
-define(WEIGHT_MIN, -32768).
-define(WEIGHT_MAX, 32767).

%% ⚠ ONE HIDDEN LAYER OF 24, AND THE SHAPE IS PART OF THE CONTRACT. Two islands
%% running different topologies produce genomes that cannot be exchanged, and
%% exchange is the whole mechanism: a captured genome has to be flyable by its
%% captor. When this changes it is a fact-version change and a roster migration,
%% not an edit.
-define(HIDDEN, [24]).

-define(MAX_WEIGHTS, 8192).

-spec scale() -> pos_integer().
scale() -> ?SCALE.

%% @doc The topology every drone in this archipelago carries.
-spec topology() -> {pos_integer(), [pos_integer()], pos_integer()}.
topology() -> {drone_senses:channels(), ?HIDDEN, drone_pilot:outputs()}.

%% @doc How many weights a topology needs: bias plus inputs, per neuron.
-spec weight_count([pos_integer()]) -> pos_integer().
weight_count(Layers) -> lists:sum(pairs(Layers)).

pairs([In, Out | Rest]) -> [Out * (In + 1) | pairs([Out | Rest])];
pairs(_Shorter) -> [].

%% @doc One time constant per hidden neuron. The output layer is not recurrent.
-spec tau_count([pos_integer()]) -> non_neg_integer().
tau_count(Layers) when length(Layers) < 3 -> 0;
tau_count(Layers) -> lists:sum(lists:sublist(Layers, 2, length(Layers) - 2)).

%% @doc Everything a genome carries: weights then time constants.
-spec gene_count([pos_integer()]) -> pos_integer().
gene_count(Layers) -> weight_count(Layers) + tau_count(Layers).

%% @doc Cut a genome's gene list into its two blocks.
-spec split([pos_integer()], [integer()]) -> {[integer()], [integer()]}.
split(Layers, Genes) -> lists:split(weight_count(Layers), Genes).

%% @doc A quantized gene to a CfC time constant.
%%
%% Linear onto [0.05, 1.0). The floor is not zero because a tau of zero is a
%% neuron with no memory at all AND a division waiting to happen; the ceiling is
%% one because a leak rate at or above it is not a leak.
-spec to_tau(integer()) -> float().
to_tau(Q) -> 0.05 + 0.95 * (Q + 32768) / 65536.

%%==============================================================================
%% The wire
%%==============================================================================

-spec pack(genome()) -> binary().
pack({Layers, Weights}) -> term_to_binary({Layers, Weights}).

-spec unpack(binary()) -> {ok, genome()} | {error, term()}.
unpack(Bin) when is_binary(Bin) -> decoded(catch binary_to_term(Bin, [safe]));
unpack(_Other) -> {error, not_a_binary}.

decoded({Layers, Weights}) when is_list(Layers), is_list(Weights) ->
    {ok, {Layers, Weights}};
decoded(_Other) -> {error, not_a_genome}.

%% @doc The content identifier: sha256 of the packed form, hex.
%%
%% Stable because the packed form is canonical, which is why there are no maps
%% and no floats in it.
-spec id(genome()) -> binary().
id(G) -> binary:encode_hex(crypto:hash(sha256, pack(G)), lowercase).

%%==============================================================================
%% The contract
%%==============================================================================

-spec limits() -> map().
limits() ->
    {In, Hidden, Out} = topology(),
    Layers = [In] ++ Hidden ++ [Out],
    #{inputs => In, hidden => Hidden, outputs => Out,
      weights => weight_count(Layers), taus => tau_count(Layers),
      genes => gene_count(Layers),
      weight_min => ?WEIGHT_MIN, weight_max => ?WEIGHT_MAX,
      max_weights => ?MAX_WEIGHTS, scale => ?SCALE}.

%% @doc Everything that must be true before a stranger's genome is run.
%%
%% ⚠ THE WIDTH CHECKS ARE NOT PEDANTRY. `network_evaluator' pads a short input
%% layer in silence and a short output vector falls back to a null command, so a
%% mismatched genome does not crash: it fights badly and produces a result that
%% looks real. That is the worst possible failure, because it is a number nobody
%% can tell from a measurement.
-spec validate(genome()) -> ok | {error, term()}.
validate({Layers, Weights}) -> checked(Layers, Weights);
validate(_Other) -> {error, not_a_genome}.

checked(Layers, _W) when not is_list(Layers) -> {error, layers_not_a_list};
checked(Layers, _W) when length(Layers) < 2 -> {error, too_few_layers};
checked(Layers, Weights) -> shaped(Layers, Weights, topology()).

shaped(Layers, _W, {In, _H, _O}) when hd(Layers) =/= In -> {error, wrong_input_width};
shaped(Layers, Weights, {_In, _H, Out}) ->
    tail_checked(lists:last(Layers) =:= Out, Layers, Weights).

tail_checked(false, _Layers, _Weights) -> {error, wrong_output_width};
tail_checked(true, Layers, Genes) -> sized(Layers, Genes, gene_count(Layers)).

sized(_L, _W, N) when N > ?MAX_WEIGHTS -> {error, too_many_weights};
sized(_L, Genes, N) when length(Genes) =/= N -> {error, wrong_weight_count};
sized(_L, Genes, _N) -> ranged(Genes).

ranged(Weights) -> in_range(lists:all(fun usable/1, Weights)).

usable(W) when is_integer(W), W >= ?WEIGHT_MIN, W =< ?WEIGHT_MAX -> true;
usable(_W) -> false.

in_range(true) -> ok;
in_range(false) -> {error, weight_out_of_range}.

%%==============================================================================
%% The float boundary
%%==============================================================================

%% @doc Floats from the trainer to the integers that are the genome.
%%
%% ⚠ CLAMPING HERE IS CORRECT AND CLAMPING IN `validate/1' WOULD NOT BE. This is
%% an optimiser proposing its own candidate, so shortening a weight it suggested
%% is a legitimate answer; a stranger's genome is a thing that already exists, and
%% changing it would make the published identifier a lie.
-spec quantize([float()]) -> [integer()].
quantize(Ws) -> [fixed:clamp(round(W * ?SCALE), ?WEIGHT_MIN, ?WEIGHT_MAX) || W <- Ws].

-spec dequantize([integer()]) -> [float()].
dequantize(Ws) -> [W / ?SCALE || W <- Ws].
