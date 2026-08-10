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
%%
%% ==========================================================================
%% ⚠⚠ AND FOR THE FIRST 150 GENERATIONS ONE OPERATOR WAS NOT ENOUGH, BECAUSE
%% THE TWO BLOCKS ARE NOT ON THE SAME SCALE
%% ==========================================================================
%%
%% Measured 2026-08-10 over all five rosters, 452 entries and 10,848 time
%% constants: **not one time constant in the archipelago was fast (below 0.2) or
%% slow (above 0.8)**, and only 2 to 7% had left the band seeding drew them from.
%% Meanwhile every entry on every island carried weights outside the seeding box.
%% Same operator, same rate, opposite outcomes. See
%% `measurements/what_is_in_the_whole_population.txt` and `REGISTER D.19`.
%%
%% The two blocks read their genes through different maps:
%%
%%   a WEIGHT  is gene/4096, so the seeded draw of +/-8192 spans [-2, 2] and one
%%             sigma of 600 moves it 0.146, about 3.7% of that span
%%   a TAU     is `drone_genome:to_tau/1`, which maps the WHOLE 16-bit range onto
%%             [0.05, 1.0), so the same +/-8192 draw covers only the middle
%%             QUARTER and one sigma of 600 moves it 0.0087, about 0.9%
%%
%% Weights are seeded across the range they use, so a gene near 2.0 leaves the
%% box on its first nudge. Time constants were seeded into the middle and had to
%% cross 0.206 of dead ground to be merely fast: 8.6 standard deviations of the
%% drift available in 150 generations, or about 11,000 generations to reach at
%% one. The range the encoding offers was not being searched, and could not be.
%%
%% So each block now gets the draw and the step its own map deserves. This is a
%% PHYSICS CHANGE: it moves the initial distribution, so it is not comparable
%% with anything bred before it and it arrived with a new lineage.
-module(breed).

-export([mutate/3, cross/3, random/1, sigma/0, tau_sigma/0]).
%% ⚠ EXPORTED FOR INSTRUMENTS, WHICH MUST NOT COPY THEM. An analysis script that
%% types the draw width in as a literal reports "how far the population has left
%% the band seeding can draw" against a band that stopped existing, and on
%% 2026-08-10 one did: it read 1581 genes outside a band the new seeding covers
%% entirely. A number that describes seeding has to come from seeding.
-export([weight_draw/0, tau_draw/0]).

%% The default perturbation, in gene units. Genes span -32768 to 32767 at Q12, so
%% 4096 is one unit of weight: a mutation of about 600 moves a weight by ~0.15,
%% which is a nudge rather than a redraw.
-define(SIGMA, 600).

%% How wide a seeded WEIGHT is drawn, in gene units: +/-8192 is +/-2 at Q12.
%% Weights are seeded across the range they are expected to use.
-define(WEIGHT_DRAW, 8192).

%% ⚠ AND A SEEDED TAU IS DRAWN ACROSS ALL OF ITS RANGE, WHICH IS THE WHOLE
%% 16-BIT SPAN. `to_tau/1' maps -32768..32767 onto [0.05, 1.0), so anything
%% narrower makes part of the encoding unreachable at birth. It was ?WEIGHT_DRAW
%% until 2026-08-10, which confined every seeded tau to [0.406, 0.644] and left
%% three quarters of the range to be crossed by drift that could not cross it.
-define(TAU_DRAW, 32768).

%% ⚠ AND THE STEP IS SCALED THE SAME WAY. Sigma is quoted in gene units, and a
%% gene unit is worth four times as much to a tau as to a weight, because a
%% weight only ever uses ?WEIGHT_DRAW either side while a tau uses the lot. Left
%% equal, a tau moves at a quarter of a weight's pace through a range four times
%% larger, which is the 16-fold difference the population measurement found.
%% Quoted as a ratio rather than a number so the two cannot drift apart.
-define(TAU_SIGMA_RATIO, (?TAU_DRAW div ?WEIGHT_DRAW)).

%% ⚠ AND THE MUTATION IS SPARSE. Perturbing all 1282 genes at once moves a
%% controller so far that a child is unrelated to its parents, which makes the
%% search a random walk with extra steps. A rate of one gene in twenty keeps a
%% child recognisably descended from what it came from.
-define(RATE_DEN, 20).

-spec sigma() -> pos_integer().
sigma() -> ?SIGMA.

%% @doc The perturbation applied to the time-constant block, in gene units.
%%
%% Larger than `sigma/0' by exactly the ratio of the two blocks' draw widths, so
%% one nudge is the same FRACTION of a tau's range as of a weight's. Derived, not
%% chosen: no number here was picked by looking at what it produced.
-spec tau_sigma() -> pos_integer().
tau_sigma() -> ?SIGMA * ?TAU_SIGMA_RATIO.

%% @doc How wide a seeded weight is drawn, in gene units.
-spec weight_draw() -> pos_integer().
weight_draw() -> ?WEIGHT_DRAW.

%% @doc How wide a seeded time constant is drawn, in gene units.
-spec tau_draw() -> pos_integer().
tau_draw() -> ?TAU_DRAW.

%% @doc A wholly random genome, for seeding a roster that has nothing in it.
%%
%% ⚠ IT TAKES ONLY THE GENERATOR. It used to take a second argument it ignored,
%% declared `pos_integer()' while every caller passed zero, and dialyzer read
%% that as a call that never returns and concluded the whole seeding recursion
%% was unreachable. The runtime was fine and the CONTRACT was a lie, which is the
%% kind of thing that makes a type checker useless by degrees.
%% ⚠⚠ THE TWO BLOCKS ARE DRAWN SEPARATELY, AND THE ORDER MATTERS. The genome is
%% weights then time constants, and `drone_genome:split/2' cuts it at
%% `weight_count/1', so the two lists are appended in that order and nowhere else.
-spec random(rand:state()) -> {drone_genome:genome(), rand:state()}.
random(S) ->
    Layers = drone_genome:layers(),
    {Ws, S1} = draws(drone_genome:weight_count(Layers), ?WEIGHT_DRAW, S, []),
    {Ts, S2} = draws(drone_genome:tau_count(Layers), ?TAU_DRAW, S1, []),
    {{Layers, Ws ++ Ts}, S2}.

draws(0, _Width, S, Acc) -> {Acc, S};
draws(N, Width, S, Acc) ->
    {R, S1} = rand:uniform_s(S),
    %% ⚠ CLAMPED, BECAUSE A FULL-WIDTH DRAW CAN LAND ON 32768 AND THE CEILING IS
    %% 32767. At the old width of 8192 this was unreachable and the clamp was not
    %% needed; at ?TAU_DRAW it is one draw in 65536, which is often enough to
    %% matter and rare enough to have shipped.
    #{weight_min := Lo, weight_max := Hi} = drone_genome:limits(),
    draws(N - 1, Width, S1, [fixed:clamp(round((R - 0.5) * 2 * Width), Lo, Hi) | Acc]).

%% @doc Perturb a genome.
%%
%% Sparse and bounded: about one gene in twenty moves, by a draw around zero, and
%% the result is clamped into range rather than wrapped. A wrapped weight would
%% turn the largest possible value into the smallest, which is not a mutation but
%% a different animal.
%%
%% ⚠ THE SIGMA GIVEN APPLIES TO THE WEIGHTS. The time-constant block is nudged at
%% `tau_sigma/0', scaled by the same ratio, so a caller that passes a custom sigma
%% still gets both blocks moved at comparable fractions of their own ranges
%% rather than silently reintroducing the imbalance this exists to remove.
-spec mutate(drone_genome:genome(), rand:state(), pos_integer()) ->
    {drone_genome:genome(), rand:state()}.
mutate({Layers, Genes}, S, Sigma) ->
    {Ws, Ts} = drone_genome:split(Layers, Genes),
    {MovedW, S1} = nudge_all(Ws, S, Sigma),
    {MovedT, S2} = nudge_all(Ts, S1, Sigma * ?TAU_SIGMA_RATIO),
    {{Layers, MovedW ++ MovedT}, S2}.

nudge_all(Genes, S, Sigma) ->
    {Moved, S1} = lists:foldl(fun (G, Acc) -> nudge(G, Acc, Sigma) end, {[], S}, Genes),
    {lists:reverse(Moved), S1}.

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
