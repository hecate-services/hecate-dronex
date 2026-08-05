%% @doc An island, as a value. PURE: no processes, no clock, no mesh.
%%
%% It holds a clock, a seeded generator, a roster of controllers and the last
%% frozen-benchmark profile it sat. `island_server' owns one of these and keeps
%% it moving; everything here is a function of what it is given.
%%
%% Kept pure for a reason a sibling paid for: once the island is a value, "did the
%% roster shrink when a sortie left" is a test over two terms, not an
%% orchestration of a gen_server, a timer and a mesh that is not there.
%%
%% ==========================================================================
%% ⚠ THE GENERATOR IS CARRIED, NOT REACHED FOR
%% ==========================================================================
%%
%% Register `D.5': one unrecorded draw in a library constructor was enough to
%% make the benchmark irreproducible and to break the property that a genome
%% specifies a controller. Every draw an island makes threads through this record,
%% so a run is a pure function of its seed and a surprising champion can be bred
%% again.
%%
%% ⚠ AND A RUN IS ONLY A PURE FUNCTION OF ITS SEED WITHIN ONE OTP RELEASE. `rand'
%% and map iteration order are not promised to agree across releases, so seed 101
%% is a different run on 28 and on 29. Every result this project records is a
%% result about the release it was measured on, and the Containerfile says which.
-module(island).

-export([new/1, run/2, train/1, seed_if_empty/1, benchmarked/2, with_roster/2]).
-export([tick_of/1, roster_depth/1, capacity/1, seed_of/1, roster_of/1]).
-export([generation_of/1, benchmark_of/1, rounds_of/1, admissions_of/1]).

-export_type([island/0]).

%% The default roster capacity. Finite on purpose: CHARTER.md prices a raid in
%% airframes, and an unbounded archive would make losing one free.
-define(DEFAULT_CAPACITY, 240).

%% How many random controllers a fresh island starts with. Smaller than the
%% capacity, because the rest of the room is what breeding fills.
-define(DEFAULT_SEEDLINGS, 32).

-record(island, {
    tick = 0 :: non_neg_integer(),
    roster :: roster:roster(),
    rand :: rand:state(),
    seed :: integer(),
    %% The last frozen-benchmark profile, and `benchmark:empty()' until one has
    %% been sat. CHARTER.md rule 4: a reader must be able to tell "sat it and lost
    %% everything" from "has not sat it", which is what a `starts' of zero says.
    benchmark :: map(),
    %% Exercise counts. A trainer that has proposed nothing and a trainer whose
    %% every proposal was rejected are different situations and look identical
    %% without these.
    rounds = 0 :: non_neg_integer(),
    admissions = 0 :: non_neg_integer()
}).

-opaque island() :: #island{}.

%% @doc A new island.
%%
%% ⚠ THE PHYSICS ARE NOT IN THE OPTIONS AND WILL NOT BE. CHARTER.md rule 2: a
%% node config may name what a node IS, its seed and its pace, and may never name
%% what the physics ARE. A sibling kept a world constant in a deployment
%% repository on a different release cadence, the node pulled the config before
%% the image that had the constant, and two of three nodes sat in a boot-crash
%% loop for two hours. The refusal to start was correct; the fault was the
%% constant's address.
-spec new(map()) -> island().
new(Opts) when is_map(Opts) ->
    Seed = maps:get(seed, Opts, 0),
    #island{seed = Seed,
            rand = rand:seed_s(exsss, {Seed, Seed + 1, Seed + 2}),
            roster = maps:get(roster, Opts,
                              roster:new(island, maps:get(capacity, Opts,
                                                          ?DEFAULT_CAPACITY))),
            benchmark = benchmark:empty()}.

%% @doc Advance the island's clock by N ticks.
%%
%% One tick is 50 ms of simulated time, which is the 20 Hz in
%% design/DESIGN_THE_AIRSPACE.md. The clock is what every fact carries, so a
%% reader can tell a stalled island from a slow one.
-spec run(island(), non_neg_integer()) -> island().
run(#island{tick = T} = I, N) when is_integer(N), N >= 0 -> I#island{tick = T + N}.

%% @doc Fill an empty roster with random controllers.
%%
%% Idempotent: an island restored from its log already has a population and is
%% left alone. Seeding over a restored roster would bury a lineage under noise.
-spec seed_if_empty(island()) -> island().
seed_if_empty(#island{roster = R} = I) -> sown(roster:depth(R) =:= 0, I).

sown(false, I) -> I;
sown(true, #island{roster = R, rand = S} = I) ->
    {R1, S1} = trainer:seed_roster(R, ?DEFAULT_SEEDLINGS, S),
    I#island{roster = R1, rand = S1}.

%% @doc One breeding round.
-spec train(island()) -> {island(), map()}.
train(#island{roster = R, rand = S, tick = T, rounds = N} = I) ->
    {R1, Report, S1} = trainer:round(R, #{rand => S, tick => T, island => bred}),
    {I#island{roster = R1, rand = S1, rounds = N + 1,
              admissions = counted(Report, I#island.admissions)},
     Report}.

counted(#{outcome := admitted}, N) -> N + 1;
counted(_Report, N) -> N.

%% @doc Record a frozen-benchmark profile.
-spec benchmarked(island(), map()) -> island().
benchmarked(#island{} = I, Profile) -> I#island{benchmark = Profile}.

%% @doc Replace the roster, for the log to restore into.
-spec with_roster(island(), roster:roster()) -> island().
with_roster(#island{} = I, R) -> I#island{roster = R}.

%%==============================================================================
%% Reading one
%%==============================================================================

-spec tick_of(island()) -> non_neg_integer().
tick_of(#island{tick = T}) -> T.

-spec roster_of(island()) -> roster:roster().
roster_of(#island{roster = R}) -> R.

-spec roster_depth(island()) -> non_neg_integer().
roster_depth(#island{roster = R}) -> roster:depth(R).

-spec capacity(island()) -> pos_integer().
capacity(#island{roster = R}) -> roster:capacity(R).

-spec generation_of(island()) -> non_neg_integer().
generation_of(#island{roster = R}) -> roster:generation_of(R).

-spec benchmark_of(island()) -> map().
benchmark_of(#island{benchmark = B}) -> B.

-spec rounds_of(island()) -> non_neg_integer().
rounds_of(#island{rounds = N}) -> N.

-spec admissions_of(island()) -> non_neg_integer().
admissions_of(#island{admissions = N}) -> N.

-spec seed_of(island()) -> integer().
seed_of(#island{seed = S}) -> S.
