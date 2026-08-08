%% @doc The island's population of controllers, as a value. PURE.
%%
%% THIS EXISTS SO AN ISLAND IS A LINEAGE RATHER THAN A RUN.
%%
%% ==========================================================================
%% ⚠ IT IS FINITE, AND THE FINITENESS IS THE MECHANISM
%% ==========================================================================
%%
%% `CHARTER.md' spends a genome when it flies: a sortie removes entries, the dead
%% do not come back, and refilling costs breeding time. An unbounded archive would
%% make losing a raid free, and a coupling with no downward pressure produces
%% stasis wearing the costume of activity. The cap is what makes a raid cost
%% something.
%%
%% ==========================================================================
%% ⚠ ADMISSION IS HEAD TO HEAD, NOT AGAINST A REMEMBERED NUMBER
%% ==========================================================================
%%
%% A candidate is admitted by beating the WORST entry on the SAME exam, evaluated
%% now, rather than by scoring above a fitness recorded when that entry was
%% admitted. Two candidates measured against different opponent samples are not
%% comparable, and a stored fitness is exactly that: a number from an exam nobody
%% is sitting any more. The trainer re-runs the incumbent, which costs one extra
%% evaluation and buys a comparison that means something.
-module(roster).

-export([new/1, new/2, admit/2, evict/2, entries/1, depth/1, capacity/1]).
-export([best/1, worst/1, sample/3, generation_of/1, take/2, restore/1]).
-export([entry/2, has/2, ids/1, tag_veteran/3, flew/1, scored/3]).
%% Reading one entry. Exported because `entry()' is opaque and reaching in with
%% `element/2' from another module is a record layout copied by hand, which stops
%% compiling in silence the day a field is inserted.
-export([entry_id/1, entry_genome/1, entry_generation/1, entry_fitness/1,
         entry_origin/1, entry_veterancy/1, entry_sorties/1]).

-export_type([roster/0, entry/0]).

-define(DEFAULT_CAPACITY, 240).

%% ⚠ `origin' AND `veteran_of' ARE PROVENANCE AND ARE NOT DECORATION. CHARTER.md
%% makes a raid the way opponent diversity crosses the mesh, so "where did this
%% controller come from" is the archipelago's central question, and a roster that
%% cannot answer it cannot be asked how much of what it holds crossed a border.
-record(entry, {
    id :: binary(),
    genome :: drone_genome:genome(),
    born_at = 0 :: non_neg_integer(),
    generation = 0 :: non_neg_integer(),
    parents = [] :: [binary()],
    %% `{bred, IslandId}' or `{captured, IslandId, RaidId}'.
    origin :: term(),
    %% The exam it was last admitted on. Kept for reporting, NEVER for
    %% comparison: see the module doc.
    fitness = 0 :: integer(),
    sorties = 0 :: non_neg_integer(),
    returns = 0 :: non_neg_integer(),
    veteran_of = [] :: [term()]
}).

-opaque entry() :: #entry{}.
-opaque roster() :: #{capacity := pos_integer(), entries := #{binary() => entry()}}.

-spec new(term()) -> roster().
new(Origin) -> new(Origin, ?DEFAULT_CAPACITY).

-spec new(term(), pos_integer()) -> roster().
new(_Origin, Capacity) when Capacity > 0 ->
    #{capacity => Capacity, entries => #{}}.

%% @doc Build an entry. Separate from `admit/2' so a caller can construct one,
%% evaluate it, and only then decide.
-spec entry(drone_genome:genome(), map()) -> entry().
entry(Genome, Opts) ->
    #entry{id = drone_genome:id(Genome),
           genome = Genome,
           born_at = maps:get(born_at, Opts, 0),
           generation = maps:get(generation, Opts, 0),
           parents = maps:get(parents, Opts, []),
           origin = maps:get(origin, Opts, unknown),
           fitness = maps:get(fitness, Opts, 0)}.

%% @doc Put an entry in, evicting the worst if the roster is full.
%%
%% ⚠ A DUPLICATE IS REFUSED RATHER THAN COUNTED TWICE. The id is the content hash
%% of the genome, so two identical controllers ARE one controller. Admitting both
%% would let a lineage inflate its own numbers by rediscovering itself, and every
%% count over the roster would stop meaning what it says.
-spec admit(roster(), entry()) -> {admitted, roster()} | {refused, term()}.
admit(#{entries := Es}, #entry{id = Id}) when is_map_key(Id, Es) ->
    {refused, already_held};
admit(#{capacity := C, entries := Es} = R, #entry{id = Id} = E)
  when map_size(Es) < C ->
    {admitted, R#{entries := Es#{Id => E}}};
admit(#{} = R, #entry{} = E) -> displaced(R, E, worst(R)).

%% Full: the newcomer takes the worst entry's place, and only if it is better.
displaced(_R, _E, undefined) -> {refused, no_room};
displaced(#{} = _R, #entry{fitness = F}, #entry{fitness = W}) when F =< W ->
    {refused, {not_better_than_worst, W}};
displaced(#{} = R, #entry{} = E, #entry{id = WorstId}) ->
    admit(evict(R, WorstId), E).

-spec evict(roster(), binary()) -> roster().
evict(#{entries := Es} = R, Id) -> R#{entries := maps:remove(Id, Es)}.

-spec entries(roster()) -> [entry()].
entries(#{entries := Es}) -> maps:values(Es).

-spec ids(roster()) -> [binary()].
ids(#{entries := Es}) -> lists:sort(maps:keys(Es)).

-spec has(roster(), binary()) -> boolean().
has(#{entries := Es}, Id) -> is_map_key(Id, Es).

-spec depth(roster()) -> non_neg_integer().
depth(#{entries := Es}) -> map_size(Es).

-spec capacity(roster()) -> pos_integer().
capacity(#{capacity := C}) -> C.

-spec best(roster()) -> entry() | undefined.
best(R) -> extreme(ordered(R), last).

-spec worst(roster()) -> entry() | undefined.
worst(R) -> extreme(ordered(R), first).

%% ⚠ SORTED BY FITNESS AND THEN BY ID. Fitness alone leaves ties broken by map
%% iteration order, which is not stable across nodes or releases, so two islands
%% holding identical rosters could disagree about which entry is worst and evict
%% different controllers. The id is the tiebreak because it is the one totally
%% ordered thing an entry has.
ordered(#{entries := Es}) ->
    lists:sort(fun (#entry{fitness = A, id = Ia}, #entry{fitness = B, id = Ib}) ->
                       {A, Ia} =< {B, Ib}
               end, maps:values(Es)).

extreme([], _Which) -> undefined;
extreme([E | _], first) -> E;
extreme(Es, last) -> lists:last(Es).

%% @doc The deepest generation this roster holds.
-spec generation_of(roster()) -> non_neg_integer().
generation_of(#{entries := Es}) when map_size(Es) =:= 0 -> 0;
generation_of(R) -> lists:max([G || #entry{generation = G} <- entries(R)]).

%% @doc `N' entries, drawn deterministically from a caller-supplied generator.
%%
%% ⚠ THE GENERATOR IS THREADED, NEVER THE PROCESS-GLOBAL ONE. Register `D.5': a
%% single unrecorded draw was enough to make the benchmark irreproducible and to
%% break the property that a genome specifies a controller. Everything that draws
%% here takes a state and returns one.
-spec sample(roster(), non_neg_integer(), rand:state()) -> {[entry()], rand:state()}.
sample(R, N, S) -> drawn(ordered(R), N, S, []).

drawn([], _N, S, Acc) -> {Acc, S};
drawn(_Pool, 0, S, Acc) -> {Acc, S};
drawn(Pool, N, S, Acc) ->
    {K, S1} = rand:uniform_s(length(Pool), S),
    drawn(Pool -- [lists:nth(K, Pool)], N - 1, S1, [lists:nth(K, Pool) | Acc]).

%% @doc Remove `N' entries for a sortie and hand them back.
%%
%% ⚠ THEY LEAVE THE ROSTER. `CHARTER.md': a genome is spent when it flies, so the
%% depth falls the moment a sortie launches and only the survivors are returned.
%% Copying them out instead would make losing a raid free.
-spec take(roster(), [binary()]) -> {[entry()], roster()}.
take(R, Ids) ->
    Taken = [E || Id <- Ids, E <- [held(R, Id)], E =/= undefined],
    {Taken, lists:foldl(fun (Id, Acc) -> evict(Acc, Id) end, R, Ids)}.

held(#{entries := Es}, Id) -> maps:get(Id, Es, undefined).

%% @doc Mark an entry as having survived a raid.
%%
%% Weismannian: the tag is EVIDENCE about the genome and changes nothing in it.
%% Whether a returning survivor also brings home changed weights is the
%% Lamarckian arm, and it is a separate decision made where the raid is settled.
-spec tag_veteran(roster(), binary(), term()) -> roster().
tag_veteran(#{entries := Es} = R, Id, Where) -> tagged(R, maps:get(Id, Es, undefined), Where).

tagged(R, undefined, _Where) -> R;
tagged(#{entries := Es} = R, #entry{veteran_of = V, returns = N} = E, Where) ->
    R#{entries := Es#{E#entry.id => E#entry{veteran_of = [Where | V], returns = N + 1}}}.

%% @doc Stamp one sortie on an entry that is LEAVING the roster.
%%
%% ⚠⚠ IT TAKES AN ENTRY AND NOT A ROSTER, AND THE VERSION THAT TOOK A ROSTER
%% COULD NEVER HAVE WORKED. `count_sortie(Roster, Id)' looked right and was two
%% separate impossibilities at once. `raid:sortie/3' calls `roster:take/2' first,
%% so by the time the count ran the id had been evicted and `maps:get/3' returned
%% `undefined': every increment was a silent no-op. And had it found the entry it
%% would have written it BACK into the map, un-evicting a party that is supposed
%% to be airborne — which is the one thing the take exists to prevent.
%%
%% Measured on beam03 on 2026-08-09, after 2,524 raids: max sorties across all 71
%% entries was 0, and every champion this archipelago has ever published carried
%% `champion_sorties => 0`.
%%
%% The count travels with the party instead. `raid:settle/3' re-admits the very
%% record it was handed, so a stamp applied on the way out is what comes home.
-spec flew(entry()) -> entry().
flew(#entry{sorties = N} = E) -> E#entry{sorties = N + 1}.

%% @doc Record a fitness against an entry already held.
%%
%% ⚠ THIS EXISTS BECAUSE A CAPTURED GENOME COULD NEVER EARN ONE. `raid:absorb/3'
%% admits a foreign genome at fitness 0 on purpose — its old number was measured
%% against somebody else's opponents and means nothing here — and says it "earns
%% a local number only if the local trainer ever sits it". The trainer sits it
%% every time it is the worst entry, and then threw the number away, so nothing
%% ever assigned one. Measured on beam03 on 2026-08-09: 52 bred entries at
%% fitness 10 to 30, and all 19 captured entries at exactly 0.
%%
%% ⚠⚠ AND THE CONSEQUENCE WAS NOT A COSMETIC ONE. `best/1' orders on stored
%% fitness, so a captured genome could never be champion, so "a controller that
%% crossed the mesh" — the archipelago's central claim — was structurally
%% unobservable rather than merely rare. The exhibit reported it as 0 of 10 for
%% weeks and that number was never evidence about the world.
-spec scored(roster(), binary(), integer()) -> roster().
scored(#{entries := Es} = R, Id, Fitness) -> rated(R, maps:get(Id, Es, undefined), Fitness).

rated(R, undefined, _Fitness) -> R;
rated(#{entries := Es} = R, #entry{} = E, Fitness) ->
    R#{entries := Es#{E#entry.id => E#entry{fitness = Fitness}}}.

%% @doc Rebuild a roster from entries, for the log to replay into.
-spec restore([entry()]) -> roster().
restore(Es) -> lists:foldl(fun put_back/2, new(unknown), Es).

put_back(E, R) -> kept(admit(R, E), R).

kept({admitted, R}, _Was) -> R;
kept({refused, _Why}, Was) -> Was.

%%==============================================================================
%% Reading one entry
%%==============================================================================

-spec entry_id(entry()) -> binary().
entry_id(#entry{id = Id}) -> Id.

-spec entry_genome(entry()) -> drone_genome:genome().
entry_genome(#entry{genome = G}) -> G.

-spec entry_generation(entry()) -> non_neg_integer().
entry_generation(#entry{generation = G}) -> G.

-spec entry_fitness(entry()) -> integer().
entry_fitness(#entry{fitness = F}) -> F.

-spec entry_origin(entry()) -> term().
entry_origin(#entry{origin = O}) -> O.

%% How many raids this controller has come home from. A parent-selection bias on
%% this is the Weismannian half of what `CHARTER.md' calls veteran status.
-spec entry_veterancy(entry()) -> non_neg_integer().
entry_veterancy(#entry{veteran_of = V}) -> length(V).

-spec entry_sorties(entry()) -> non_neg_integer().
entry_sorties(#entry{sorties = N}) -> N.
