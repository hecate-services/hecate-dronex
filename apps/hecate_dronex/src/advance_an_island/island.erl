%% @doc An island, as a value. PURE: no processes, no clock, no mesh.
%%
%% ⚠ IT DOES ALMOST NOTHING AT THIS COMMIT AND THE SHAPE IS THE POINT. Order of
%% work item 1 is the spine, so an island holds a clock, a seed and an empty
%% roster, and `run/2' advances the clock. The airspace, the drones, the trainer
%% and the static defence arrive at items 2 to 8 and each one lands HERE, in a
%% value a test can build without a running node.
%%
%% Kept pure for a reason a sibling paid for: once the island is a value, "did
%% the roster shrink when a sortie left" is a test over two terms, not an
%% orchestration of a gen_server, a timer and a mesh that is not there.
%%
%% ==========================================================================
%% THE SEED IS CARRIED, NOT USED, AND THAT IS DELIBERATE
%% ==========================================================================
%%
%% Nothing here is random yet. The seed is threaded through from the first commit
%% because retrofitting determinism is the expensive direction: every island that
%% draws from the process-global generator has to be found and rewritten, and the
%% ones that were missed look fine.
%%
%% ⚠ AND A RUN IS ONLY A PURE FUNCTION OF ITS SEED WITHIN ONE OTP RELEASE. `rand'
%% and map iteration order are not promised to agree across releases, so seed 101
%% is a different run on 28 and on 29. Every result this project records is a
%% result about the release it was measured on, and the Containerfile says which.
-module(island).

-export([new/1, run/2]).
-export([tick_of/1, roster_depth/1, capacity/1, seed_of/1]).

-export_type([island/0]).

%% The default roster capacity. Finite on purpose: CHARTER.md prices a raid in
%% airframes, and an unbounded archive would make losing one free.
-define(DEFAULT_CAPACITY, 240).

-record(island, {
    tick = 0 :: non_neg_integer(),
    %% ⚠ EMPTY, AND NOTHING FILLS IT YET. The roster arrives at item 5 with the
    %% trainer and with persistence. Until then `roster_depth/1' honestly reports
    %% nothing rather than the field being absent from the wire.
    roster = [] :: [term()],
    capacity = ?DEFAULT_CAPACITY :: pos_integer(),
    seed :: integer()
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
    #island{seed = maps:get(seed, Opts, 0),
            capacity = maps:get(capacity, Opts, ?DEFAULT_CAPACITY)}.

%% @doc Advance the island by N ticks.
%%
%% One tick is 50 ms of simulated time, which is the 20 Hz in
%% design/DESIGN_THE_AIRSPACE.md. Nothing consumes that yet; the clock exists so
%% that every fact carries a tick from the first one published, and a reader can
%% tell a stalled island from a slow one before there is anything to stall.
-spec run(island(), non_neg_integer()) -> island().
run(#island{tick = T} = I, N) when is_integer(N), N >= 0 -> I#island{tick = T + N}.

-spec tick_of(island()) -> non_neg_integer().
tick_of(#island{tick = T}) -> T.

-spec roster_depth(island()) -> non_neg_integer().
roster_depth(#island{roster = R}) -> length(R).

-spec capacity(island()) -> pos_integer().
capacity(#island{capacity = C}) -> C.

-spec seed_of(island()) -> integer().
seed_of(#island{seed = S}) -> S.
