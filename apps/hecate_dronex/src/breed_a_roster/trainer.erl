%% @doc One round of breeding: propose a controller, and keep it if it earns a
%% place. PURE, and every draw is threaded.
%%
%% ==========================================================================
%% STEADY STATE, NOT GENERATIONAL, AND THE REASON IS THE ISLAND
%% ==========================================================================
%%
%% An island has to keep publishing, keep answering raids and keep sitting its
%% benchmark while the search runs. A generational loop owns its own scheduling
%% and would either block all of that or have to be interrupted mid-generation,
%% which leaves a population half-replaced. One round here is small, bounded and
%% resumable: the island calls it when it has time.
%%
%% ==========================================================================
%% ⚠ FITNESS IS A SCALAR AND THE BENCHMARK IS NOT, AND THAT IS NOT A CONTRADICTION
%% ==========================================================================
%%
%% `benchmark' refuses to produce a single number, because it is an INSTRUMENT and
%% a weighted total would smuggle a judgement about which rung matters into a
%% measurement. Selection is the opposite kind of thing: it has to order two
%% candidates, so it needs one number by definition.
%%
%% They are also measured against different opponents. The benchmark is FROZEN and
%% never trained against; fitness is measured against the opponent set, which
%% raids will widen. Keeping them apart is what makes "the island got better" a
%% sentence about the drones rather than about the exam.
%%
%% ==========================================================================
%% ⚠⚠ THE CHALLENGER AND THE INCUMBENT SIT THE SAME EXAM, NOW
%% ==========================================================================
%%
%% A stored fitness is a number from an exam nobody is sitting any more: the
%% opponent sample differs from round to round, so comparing a fresh score with a
%% remembered one compares two different tests. The incumbent is re-run against
%% the same opponents and the same starts, which costs one extra evaluation and
%% buys a comparison that means something.
-module(trainer).

-export([round/2, evaluate/4, seed_roster/3, opponents/1, points/1]).

%% How many opponents and how many starts one evaluation uses. Small on purpose:
%% a round is meant to be cheap and frequent rather than thorough, and the frozen
%% benchmark is what says whether any of it worked.
-define(OPPONENTS, 4).
-define(STARTS, 4).

%% Two for a win and one for a draw, which is football's convention and needs no
%% justification beyond being a convention. What matters is that it is stated
%% here rather than implied by an ordering somewhere else.
-define(WIN_POINTS, 2).
-define(DRAW_POINTS, 1).

%% @doc Fill an empty roster with random controllers.
%%
%% ⚠ THE FIRST POPULATION IS RANDOM AND IS NOT SCREENED. A sibling drew candidate
%% worlds until it found a viable one, which is right when most seeds die at once;
%% here a controller that cannot fly simply loses every engagement and is evicted
%% by the first thing that can, so the search does the screening and nothing has
%% to guess what viable means in advance.
-spec seed_roster(roster:roster(), pos_integer(), rand:state()) ->
    {roster:roster(), rand:state()}.
seed_roster(R, 0, S) -> {R, S};
seed_roster(R, N, S) ->
    {Genome, S1} = breed:random(S, 0),
    Entry = roster:entry(Genome, #{origin => {bred, seeded}, generation => 0}),
    seed_roster(kept(roster:admit(R, Entry), R), N - 1, S1).

kept({admitted, R}, _Was) -> R;
kept({refused, _Why}, Was) -> Was.

%% @doc One round: breed a challenger, sit it and the incumbent worst on the same
%% exam, and admit the challenger if it wins the comparison.
-spec round(roster:roster(), map()) -> {roster:roster(), map(), rand:state()}.
round(R, Opts) -> proposed(R, Opts, roster:depth(R)).

%% Nothing to breed from. The island seeds before it trains, so this is the
%% degenerate case rather than the normal one.
proposed(R, #{rand := S}, Depth) when Depth < 2 ->
    {R, #{outcome => too_few_parents}, S};
proposed(R, #{rand := S} = Opts, _Depth) ->
    {Parents, S1} = roster:sample(R, 2, S),
    bred(R, Opts, Parents, S1).

bred(R, Opts, [A, B], S) -> varied(R, Opts, {A, B}, breed:cross(genome(A), genome(B), S));
bred(R, #{rand := S}, _Few, _S) -> {R, #{outcome => too_few_parents}, S}.

varied(R, #{rand := _} = Opts, _Pair, {error, Why}) ->
    {R, #{outcome => {refused, Why}}, maps:get(rand, Opts)};
varied(R, Opts, {A, B}, {ok, Crossed, S}) ->
    {Child, S1} = breed:mutate(Crossed, S, maps:get(sigma, Opts, breed:sigma())),
    contested(R, Opts, {A, B}, Child, S1).

%% ⚠ THE SAME OPPONENTS AND THE SAME STARTS FOR BOTH, DRAWN ONCE. Drawing twice
%% would give the challenger and the incumbent different exams, which is the
%% failure this whole arrangement exists to avoid.
contested(R, Opts, {A, B}, Child, S) ->
    {Opps, S1} = opponent_sample(R, S),
    {Starts, S2} = start_sample(S1),
    Incumbent = roster:worst(R),
    Theirs = evaluate(genome(Incumbent), Opps, Starts, R),
    Mine = evaluate(Child, Opps, Starts, R),
    judged(R, Opts, {A, B}, Child, Mine, Theirs, S2).

judged(R, _Opts, _Pair, _Child, Mine, Theirs, S) when Mine =< Theirs ->
    {R, #{outcome => rejected, challenger => Mine, incumbent => Theirs}, S};
judged(R, Opts, {A, B}, Child, Mine, Theirs, S) ->
    Entry = roster:entry(Child,
                         #{origin => {bred, maps:get(island, Opts, unknown)},
                           born_at => maps:get(tick, Opts, 0),
                           generation => 1 + max(generation(A), generation(B)),
                           parents => [id(A), id(B)],
                           fitness => Mine}),
    admitted(roster:admit(R, Entry), R, Mine, Theirs, S).

admitted({admitted, R2}, _Was, Mine, Theirs, S) ->
    {R2, #{outcome => admitted, challenger => Mine, incumbent => Theirs}, S};
admitted({refused, Why}, Was, Mine, Theirs, S) ->
    {Was, #{outcome => {refused, Why}, challenger => Mine, incumbent => Theirs}, S}.

%%==============================================================================
%% The exam
%%==============================================================================

%% @doc Points scored by a genome against a list of opponents over a list of
%% start indexes.
%%
%% ⚠ IT REFUSES A GENOME IT CANNOT FLY RATHER THAN SCORING IT ZERO. A zero is a
%% legitimate score for a controller that lost everything, so using it for a
%% controller that never ran would make the two indistinguishable, and a bug in
%% validation would look like a population that had got worse.
-spec evaluate(drone_genome:genome(), [term()], [non_neg_integer()], roster:roster()) ->
    integer().
evaluate(Genome, Opponents, Starts, R) ->
    flown(engagement:controller(Genome), Genome, Opponents, Starts, R).

flown({error, _Why}, _G, _Opps, _Starts, _R) -> -1;
flown({ok, _P}, Genome, Opponents, Starts, R) ->
    lists:sum([bout(Genome, O, I, R) || O <- Opponents, I <- Starts]).

bout(Genome, Opponent, Index, R) ->
    {ok, Mine} = engagement:controller(Genome),
    against(Mine, opponent_controller(Opponent, R), Index).

against(_Mine, {error, _Why}, _Index) -> 0;
against(Mine, {ok, Theirs}, Index) ->
    Placed = drone_starts:place(1, 1, Index),
    [{AId, _, _, _, _, _}, {DId, _, _, _, _, _}] = Placed,
    Result = engagement:run(airspace:new(Placed), #{AId => Mine, DId => Theirs}),
    points(maps:get(winner, Result)).

-spec points(attacker | defender | draw) -> integer().
points(attacker) -> ?WIN_POINTS;
points(draw) -> ?DRAW_POINTS;
points(defender) -> 0.

%% ⚠ THE OPPONENT SET IS THE DRILLS PLUS THIS ISLAND'S OWN ROSTER, and at item 7
%% it gains every foreign genome that has ever attacked here. That widening is
%% CHARTER.md's one idea in mechanical form: a raid moves opponents rather than
%% assigning fitness, so selection stays local against a set that raids make more
%% diverse.
-spec opponents(roster:roster()) -> [term()].
opponents(R) -> drone_drills:kinds() ++ [id(E) || E <- roster:entries(R)].

opponent_sample(R, S) -> pick_n(opponents(R), ?OPPONENTS, S, []).

pick_n(_Pool, 0, S, Acc) -> {Acc, S};
pick_n([], _N, S, Acc) -> {Acc, S};
pick_n(Pool, N, S, Acc) ->
    {K, S1} = rand:uniform_s(length(Pool), S),
    Chosen = lists:nth(K, Pool),
    pick_n(Pool -- [Chosen], N - 1, S1, [Chosen | Acc]).

start_sample(S) -> pick_n(lists:seq(0, drone_starts:count() - 1), ?STARTS, S, []).

%% A drill kind is an atom; a roster entry is referred to by its id.
opponent_controller(Kind, _R) when is_atom(Kind) -> engagement:controller(Kind);
opponent_controller(Id, R) -> from_roster(roster:entries(R), Id).

from_roster(Es, Id) -> built([E || E <- Es, id(E) =:= Id]).

built([E | _]) -> engagement:controller(genome(E));
built([]) -> {error, gone}.

%%==============================================================================
%% Reaching into an entry
%%==============================================================================
%%
%% Through `roster''s accessors rather than `element/2', because the entry is
%% opaque and a hand-copied record layout stops compiling in silence the day a
%% field is inserted.

genome(E) -> roster:entry_genome(E).
id(E) -> roster:entry_id(E).
generation(E) -> roster:entry_generation(E).
