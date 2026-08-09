%% @doc Every kind of invader this island has ever faced, kept across ERAS. PURE.
%%
%% THIS EXISTS BECAUSE THE PROBLEM IS "DEFEAT INVADERS", NOT "WIN A LEAGUE".
%%
%% ==========================================================================
%% ⚠ WHAT THE ARCHIPELAGO IS FOR, STATED WHERE THE INSTRUMENT LIVES
%% ==========================================================================
%%
%% The islands are not competitors and ranking them is not the point. They are a
%% way to spread the load of one search across a mesh and to make the opponents
%% diverse, and the thing being searched for is a population of controllers that
%% can beat what comes at it. Where a controller was bred does not matter.
%%
%% So the measure that matters is not "which island is best" but "can what we
%% have now beat what has ever attacked us" — and, critically, whether that is
%% still true of the things that attacked us a long time ago.
%%
%% ==========================================================================
%% ⚠⚠ IT IS HELD OUT FROM TRAINING, AND THAT IS THE WHOLE REASON IT IS A
%% SEPARATE COLLECTION FROM THE ROSTER
%% ==========================================================================
%%
%% `raid:absorb/3' admits captured genomes into the roster, deliberately: that is
%% CHARTER.md's one idea, opponent diversity crossing the mesh, and the trainer
%% then has to beat them. `trainer:opponents/1' is every roster entry.
%%
%% An archive built from those same genomes would be a test set inside the
%% training distribution, which is `REGISTER I.22' exactly — the fault that made
%% the frozen exam meaningless for the whole life of this track, found and fixed
%% on 2026-08-08. Building the next instrument the same way on 2026-08-09 would
%% be paying for it twice.
%%
%% So a raid's haul is SPLIT. Most of it goes to the roster as opponents; a fixed
%% share is sequestered here and is never admitted, never bred from, never an
%% opponent in a training round. `invaders_tests' asserts the disjointness rather
%% than this comment promising it.
%%
%% ==========================================================================
%% ⚠⚠⚠ ERAS, BECAUSE A MASTER TOURNAMENT EXISTS TO DETECT CYCLING
%% ==========================================================================
%%
%% A coevolving population can improve against what it is fighting NOW and lose
%% to what it beat a month ago, going round in a circle while every local number
%% rises. That is the failure a master tournament is for, and it is invisible to
%% any archive that keeps only recent arrivals.
%%
%% An entry's era is the base-2 logarithm of its age, so the bands are 1 tick, 2,
%% 4, 8 and so on. That is self-maintaining: recent invaders are numerous and
%% land in low bands, ancient ones are few and each holds its own high band, and
%% nothing has to be rebalanced as time passes. When the archive is full it drops
%% from the band that is FULLEST, so the oldest eras cannot be squeezed out by a
%% busy afternoon.
-module(invaders).

-export([new/0, new/1, witness/5, holds/2, depth/1, capacity/1, entries/1]).
-export([bands/2, group/2, sample/4, era_of/2, ids/1]).
-export([entry_id/1, entry_genome/1, entry_from/1, entry_seen_at/1, entry_raid/1]).
-export([sequestered/2, share/0]).

-export_type([archive/0, entry/0]).

-record(invader, {
    id :: binary(),
    genome :: drone_genome:genome(),
    %% Which island bred it. The archive is a record of who has attacked, so this
    %% is the half of the story a genome id cannot carry.
    from :: binary(),
    raid :: binary(),
    %% The island's own tick when it arrived. Eras are computed from this, so it
    %% is the one field the whole instrument rests on.
    seen_at :: non_neg_integer()
}).

-opaque entry() :: #invader{}.
-opaque archive() :: #{cap := pos_integer(), entries := #{binary() => entry()}}.

%% ⚠ SMALL, AND SMALLER THAN THE ROSTER ON PURPOSE. Every entry here is flown
%% against the champion when the tournament sits, so the archive's size is
%% directly the cost of the measurement. 96 across all eras is enough to say
%% whether an era has been forgotten and cheap enough to fly on a Celeron.
-define(DEFAULT_CAPACITY, 96).

%% ⚠⚠ ONE IN FOUR OF A RAID'S HAUL IS SEQUESTERED, and the split is by a hash of
%% the genome id rather than by a draw. A random split would put the same genome
%% in the training set on one island and the test set on another, which is
%% defensible; a deterministic one makes the split reproducible from the id
%% alone, so anybody can check that a given controller was held out here without
%% being told.
-define(SEQUESTER_ONE_IN, 4).

-spec new() -> archive().
new() -> new(?DEFAULT_CAPACITY).

-spec new(pos_integer()) -> archive().
new(Cap) when is_integer(Cap), Cap > 0 -> #{cap => Cap, entries => #{}}.

-spec capacity(archive()) -> pos_integer().
capacity(#{cap := C}) -> C.

-spec depth(archive()) -> non_neg_integer().
depth(#{entries := Es}) -> maps:size(Es).

-spec entries(archive()) -> [entry()].
entries(#{entries := Es}) -> maps:values(Es).

-spec ids(archive()) -> [binary()].
ids(#{entries := Es}) -> maps:keys(Es).

-spec holds(archive(), binary()) -> boolean().
holds(#{entries := Es}, Id) -> maps:is_key(Id, Es).

%% @doc Which share of a haul is held out, for a caller that wants to say so.
-spec share() -> pos_integer().
share() -> ?SEQUESTER_ONE_IN.

%% @doc Whether this genome is one of the held-out ones.
%%
%% ⚠ FROM THE ID ALONE, so the same genome is sequestered on whichever island
%% meets it and a reader can check the split without being told what it was. The
%% id is the sha256 of the packed genome, so its low bits are as good a coin as
%% any and cost nothing to compute.
-spec sequestered(binary(), pos_integer()) -> boolean().
sequestered(Id, OneIn) when is_binary(Id), Id =/= <<>> ->
    binary:last(Id) rem OneIn =:= 0;
sequestered(_Id, _OneIn) -> false.

%% @doc Offer an invader to the archive.
%%
%% Idempotent on the id: an island raided twice by the same controller holds it
%% once, and re-admitting would reset the era it belongs to and quietly make an
%% old invader look new.
-spec witness(archive(), drone_genome:genome(), binary(), binary(),
              non_neg_integer()) -> archive().
witness(A, Genome, From, Raid, Now) ->
    kept(A, drone_genome:id(Genome), Genome, From, Raid, Now).

kept(#{entries := Es} = A, Id, Genome, From, Raid, Now) ->
    case maps:is_key(Id, Es) of
        true -> A;
        false -> admitted(A, #invader{id = Id, genome = Genome, from = From,
                                      raid = Raid, seen_at = Now}, Now)
    end.

admitted(#{cap := Cap, entries := Es} = A, #invader{} = E, Now) ->
    room(maps:size(Es) < Cap, A, E, Now).

room(true, #{entries := Es} = A, #invader{id = Id} = E, _Now) ->
    A#{entries := Es#{Id => E}};
%% ⚠ FULL: DROP FROM THE FULLEST ERA, NEVER THE OLDEST ENTRY. Evicting the oldest
%% is the obvious policy and it is exactly wrong here — it empties the very bands
%% the instrument exists to keep, so the archive would drift into "the last
%% hundred invaders" and could no longer tell progress from cycling.
room(false, A, #invader{} = E, Now) ->
    displaced(A, E, crowded(bands(A, Now))).

displaced(A, _E, undefined) -> A;
displaced(#{entries := Es} = A, #invader{id = Id} = E, Evict) ->
    A#{entries := maps:put(Id, E, maps:remove(Evict, Es))}.

%% The fullest band, and within it the highest id. The id is the tiebreak for the
%% same reason the roster uses it: map iteration order is not stable across nodes
%% or releases, so two islands holding identical archives would otherwise disagree
%% about what they dropped.
crowded(Bands) ->
    case lists:reverse(lists:keysort(1, [{length(Es), B} || {B, Es} <- maps:to_list(Bands)])) of
        [] -> undefined;
        [{_N, Band} | _] -> lists:max([E#invader.id || E <- maps:get(Band, Bands)])
    end.

%% @doc The era an entry belongs to at time `Now': the base-2 log of its age.
%%
%% Band 0 is the tick it arrived, band 10 is roughly a thousand ticks ago, band 20
%% roughly a million. Ages are unbounded above and the bands are not, which is the
%% property that makes ancient invaders survive without a policy.
-spec era_of(entry(), non_neg_integer()) -> non_neg_integer().
era_of(#invader{seen_at = At}, Now) when Now > At -> log2(Now - At);
era_of(#invader{}, _Now) -> 0.

log2(N) when N > 0 -> trunc(math:log2(N)).

%% @doc The archive grouped by era, oldest era being the highest number.
-spec bands(archive(), non_neg_integer()) -> #{non_neg_integer() => [entry()]}.
bands(A, Now) -> group(entries(A), Now).

%% @doc The same grouping over a LIST of entries, for a caller holding a sample.
%%
%% ⚠ EXPORTED SO `master' DOES NOT KEEP ITS OWN COPY. It had one, byte for byte,
%% and two implementations of "which era is this in" is two places for the
%% instrument's central definition to drift.
-spec group([entry()], non_neg_integer()) -> #{non_neg_integer() => [entry()]}.
group(Es, Now) -> lists:foldl(fun (E, Acc) -> banded(E, Now, Acc) end, #{}, Es).

%% Flat rather than a fun inside a fun inside a fold: elvis caps nesting at two
%% and it is right to, because the version with three was harder to read than
%% this and said nothing more.
banded(E, Now, Acc) ->
    maps:update_with(era_of(E, Now), fun (Es) -> [E | Es] end, [E], Acc).

%% @doc Up to `N' invaders, spread across eras rather than drawn from the whole.
%%
%% ⚠ ONE FROM EACH ERA BEFORE A SECOND FROM ANY, which is the difference between
%% a master tournament and a random sample. A flat draw over an archive whose
%% recent band holds fifty entries and whose oldest holds one will almost never
%% fly the old one, so the measurement would answer "can we beat what is
%% attacking us lately" — a question the roster already answers.
-spec sample(archive(), pos_integer(), non_neg_integer(), rand:state()) ->
    {[entry()], rand:state()}.
sample(A, N, Now, S) ->
    Ordered = [{B, lists:keysort(#invader.id, Es)} || {B, Es} <- lists:sort(maps:to_list(bands(A, Now)))],
    round_robin(Ordered, N, S, []).

round_robin(_Bands, 0, S, Acc) -> {lists:reverse(Acc), S};
round_robin([], _N, S, Acc) -> {lists:reverse(Acc), S};
round_robin(Bands, N, S, Acc) ->
    {Taken, Rest, S1} = one_per_band(Bands, N, S, [], []),
    keep_going(Taken, Rest, N - length(Taken), S1, Taken ++ Acc).

keep_going([], _Rest, _N, S, Acc) -> {lists:reverse(Acc), S};
keep_going(_Taken, Rest, N, S, Acc) -> round_robin(Rest, N, S, Acc).

one_per_band([], _N, S, Taken, Rest) -> {Taken, lists:reverse(Rest), S};
one_per_band(_Bands, 0, S, Taken, Rest) -> {Taken, lists:reverse(Rest), S};
one_per_band([{_B, []} | More], N, S, Taken, Rest) ->
    one_per_band(More, N, S, Taken, Rest);
one_per_band([{B, Es} | More], N, S, Taken, Rest) ->
    {K, S1} = rand:uniform_s(length(Es), S),
    Chosen = lists:nth(K, Es),
    one_per_band(More, N - 1, S1, [Chosen | Taken], [{B, Es -- [Chosen]} | Rest]).

-spec entry_id(entry()) -> binary().
entry_id(#invader{id = Id}) -> Id.

-spec entry_genome(entry()) -> drone_genome:genome().
entry_genome(#invader{genome = G}) -> G.

-spec entry_from(entry()) -> binary().
entry_from(#invader{from = F}) -> F.

-spec entry_raid(entry()) -> binary().
entry_raid(#invader{raid = R}) -> R.

-spec entry_seen_at(entry()) -> non_neg_integer().
entry_seen_at(#invader{seen_at = At}) -> At.
