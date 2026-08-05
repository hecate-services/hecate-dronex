%% @doc Variation: how a new controller is made from old ones. PURE and SEEDED.
%%
%% THIS EXISTS BECAUSE SELECTION WITHOUT VARIATION IS NOT EVOLUTION. A sibling
%% line shipped a population that was admitted into and never varied, and its own
%% record calls that what it was: a hall of fame with immigration. Variation plus
%% fitness plus selection is the mechanism, and this is the first of the three.
%%
%% ==========================================================================
%% ⚠ EVERY DRAW IS THREADED. THERE IS NO PROCESS-GLOBAL GENERATOR HERE.
%% ==========================================================================
%%
%% Register `D.5': one unrecorded draw, in a library constructor, was enough to
%% make the benchmark irreproducible AND to break the property that a genome
%% specifies a controller. Every function below takes a `rand:state()' and
%% returns one, so a breeding run is a pure function of the seed it started from
%% and a surprising champion can be produced again.
%%
%% ==========================================================================
%% THE GENOME IS ONE FLAT VECTOR, WEIGHTS THEN TIME CONSTANTS
%% ==========================================================================
%%
%% So one operator varies both, and the memory's timescale is selected along with
%% everything else rather than being a constant somebody chose. That is what a
%% learnable time constant is supposed to mean.
-module(breed).

-export([mutate/3, cross/3, random/2, sigma/0]).

%% The default perturbation, in gene units. Genes span -32768 to 32767 at Q12, so
%% 4096 is one unit of weight: a mutation of about 600 moves a weight by ~0.15,
%% which is a nudge rather than a redraw.
-define(SIGMA, 600).

%% ⚠ AND THE MUTATION IS SPARSE. Perturbing all 1282 genes at once moves a
%% controller so far that a child is unrelated to its parents, which makes the
%% search a random walk with extra steps. A rate of one gene in twenty keeps a
%% child recognisably descended from what it came from.
-define(RATE_DEN, 20).

-spec sigma() -> pos_integer().
sigma() -> ?SIGMA.

%% @doc A wholly random genome, for seeding a roster that has nothing in it.
-spec random(rand:state(), pos_integer()) -> {drone_genome:genome(), rand:state()}.
random(S, _Unused) ->
    {In, Hidden, Out} = drone_genome:topology(),
    Layers = [In] ++ Hidden ++ [Out],
    {Genes, S1} = draws(drone_genome:gene_count(Layers), S, []),
    {{Layers, Genes}, S1}.

draws(0, S, Acc) -> {Acc, S};
draws(N, S, Acc) ->
    {R, S1} = rand:uniform_s(S),
    draws(N - 1, S1, [round((R - 0.5) * 2 * 8192) | Acc]).

%% @doc Perturb a genome.
%%
%% Sparse and bounded: about one gene in twenty moves, by a draw around zero, and
%% the result is clamped into range rather than wrapped. A wrapped weight would
%% turn the largest possible value into the smallest, which is not a mutation but
%% a different animal.
-spec mutate(drone_genome:genome(), rand:state(), pos_integer()) ->
    {drone_genome:genome(), rand:state()}.
mutate({Layers, Genes}, S, Sigma) ->
    {Moved, S1} = lists:foldl(fun (G, Acc) -> nudge(G, Acc, Sigma) end, {[], S}, Genes),
    {{Layers, lists:reverse(Moved)}, S1}.

nudge(G, {Acc, S}, Sigma) ->
    {R, S1} = rand:uniform_s(?RATE_DEN, S),
    shifted(R =:= 1, G, {Acc, S1}, Sigma).

shifted(false, G, {Acc, S}, _Sigma) -> {[G | Acc], S};
shifted(true, G, {Acc, S}, Sigma) ->
    {D, S1} = gaussian(S, Sigma),
    #{weight_min := Lo, weight_max := Hi} = drone_genome:limits(),
    {[fixed:clamp(G + D, Lo, Hi) | Acc], S1}.

%% Box-Muller, which needs two uniforms and one log and one cosine.
%%
%% ⚠ FLOAT MATH IS FINE HERE AND WOULD NOT BE IN THE ARENA. This runs while
%% BREEDING, not while fighting: its output is quantized into a gene immediately
%% and the gene is what everything downstream sees. Nothing about a published
%% fight depends on it.
gaussian(S, Sigma) ->
    {U1, S1} = rand:uniform_s(S),
    {U2, S2} = rand:uniform_s(S1),
    Z = math:sqrt(-2.0 * math:log(U1)) * math:cos(2.0 * math:pi() * U2),
    {round(Z * Sigma), S2}.

%% @doc Recombine two genomes, gene by gene.
%%
%% ⚠ UNIFORM RATHER THAN SINGLE-POINT, and the reason is the genome's layout.
%% Weights come first and time constants last, so a single cut point would almost
%% always fall in the weights and the child would take every time constant from
%% one parent. Uniform crossover mixes both blocks.
%%
%% ⚠⚠ MISMATCHED TOPOLOGIES REFUSE RATHER THAN TRUNCATING. Two genomes of
%% different shape have no gene-to-gene correspondence at all, so a child of them
%% would be an arbitrary splice presented as a descendant.
-spec cross(drone_genome:genome(), drone_genome:genome(), rand:state()) ->
    {ok, drone_genome:genome(), rand:state()} | {error, term()}.
cross({La, _A}, {Lb, _B}, _S0) when La =/= Lb -> {error, topology_mismatch};
cross({_L, A}, {_L2, B}, _S) when length(A) =/= length(B) -> {error, gene_count_mismatch};
cross({L, A}, {_L, B}, S) ->
    {Genes, S1} = lists:foldl(fun pick/2, {[], S}, lists:zip(A, B)),
    {ok, {L, lists:reverse(Genes)}, S1}.

pick({Ga, Gb}, {Acc, S}) ->
    {R, S1} = rand:uniform_s(2, S),
    {[chosen(R, Ga, Gb) | Acc], S1}.

chosen(1, Ga, _Gb) -> Ga;
chosen(2, _Ga, Gb) -> Gb.
