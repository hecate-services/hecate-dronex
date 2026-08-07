%% @doc The one process allowed to block on the store.
%%
%% THIS EXISTS BECAUSE A STORE WRITE ONCE WEDGED THE ISLAND FOR FOUR MINUTES,
%% ON A FLEET NODE, WITHIN TWENTY MINUTES OF THE FIRST DEPLOY.
%%
%% ==========================================================================
%% ⚠ WHAT ACTUALLY HAPPENED, BECAUSE THE SHAPE OF THE FIX FOLLOWS FROM IT
%% ==========================================================================
%%
%% `roster_log' wrote with the stream id `roster', which reckon-db rejects:
%% a user stream must be `<prefix>-<32 hex>' and a system stream `$<ns>:<name>'.
%% The rejection is raised as an EXIT from the gateway worker rather than
%% returned as an error, so `reckon_gater_retry' could not recognise it as the
%% non-retriable validation failure it is, and retried eleven times with
%% exponential backoff.
%%
%% All of that happened INSIDE `island_server:handle_info(snapshot, ...)'.
%%
%% ⚠⚠ AND SO THE ISLAND STOPPED. Not crashed: stopped. The clock did not
%% advance, nothing was published, `/health' answered `ok' throughout, and the
%% container reported `healthy'. Every gen_server call into it timed out, which
%% reads exactly like a wedged process and was in fact a busy one. The stream id
%% was our bug; blocking the island on a store write was the DESIGN's, and the
%% stream id merely found it.
%%
%% CLAUDE.md has carried the rule the whole time: DB I/O belongs to a dedicated
%% worker and NEVER blocks the flow. This is that worker.
%%
%% ==========================================================================
%% ⚠ IT COALESCES, AND WITHOUT THAT IT WOULD ONLY MOVE THE PROBLEM
%% ==========================================================================
%%
%% A roster snapshot is FULL STATE, so the newest one makes every older one
%% pointless. A plain queue in front of a slow store would grow by 1.5 MB every
%% two minutes and the writer would fall further behind for ever, writing history
%% nobody wants. Draining the mailbox and keeping only the last request means a
%% slow store costs staleness, which is bounded, instead of memory, which is not.
%%
%% The count of what was DROPPED is kept and published. CHARTER.md rule 4: a
%% writer that has skipped four hundred snapshots and one that has skipped none
%% must not look the same.
-module(roster_log_writer).

-behaviour(gen_server).

-export([start_link/0, snapshot/3, stats/0, silent/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Ask for the roster to be written. Returns immediately, always.
%%
%% ⚠ A CAST, AND THE ASYMMETRY IS THE WHOLE POINT. The caller is the island and
%% it must never wait on a disk. What it gets back instead is `stats/0', which
%% says whether the writing is actually happening.
%% The tally travels with the roster because they are written as one event: this
%% population, having done these things. See `roster_log:snapshot/3'.
-spec snapshot(atom(), roster:roster(), map()) -> ok.
snapshot(StoreId, Roster, Tally) ->
    gen_server:cast(?MODULE, {snapshot, StoreId, Roster, Tally}).

%% @doc Exercise counts. `dropped' is snapshots superseded before they were
%% written, which is normal and healthy; `failed' is writes the store refused.
-spec stats() -> #{written := non_neg_integer(),
                   failed := non_neg_integer(),
                   dropped := non_neg_integer()}.
stats() -> gen_server:call(?MODULE, stats, 5000).

%% @doc The counts before anything has been written, for a reader that starts
%% before the writer has spoken. CHARTER.md rule 4: zeros go out from the first
%% fact rather than the field being absent until it has a value.
-spec silent() -> #{written := 0, failed := 0, dropped := 0}.
silent() -> #{written => 0, failed => 0, dropped => 0}.

init([]) -> {ok, silent()}.

handle_call(stats, _From, S) -> {reply, maps:with([written, failed, dropped], S), S};
handle_call(_Other, _From, S) -> {reply, {error, unknown_call}, S}.

handle_cast({snapshot, StoreId, Roster, Tally}, S) ->
    {Latest, Skipped} = newest({StoreId, Roster, Tally}, 0),
    {noreply, told(written(write(Latest), S#{dropped := maps:get(dropped, S) + Skipped}))};
handle_cast(_Msg, S) -> {noreply, S}.

%% ⚠ THE WRITER TELLS, THE ISLAND NEVER ASKS. `stats/0' is a call, so an island
%% that polled it would block on a writer that is blocked on a store — which is
%% precisely the failure this module exists to remove, reintroduced one level
%% further out. A cast after each drain cannot block anybody.
%%
%% Nothing may be listening: `roster_log_writer' is started before
%% `island_server' and outlives its restarts, and a cast to a dead name is a
%% silent no-op, which is the correct outcome here.
told(S) ->
    _ = gen_server:cast(island_server, {roster_written, maps:with([written, failed, dropped], S)}),
    S.

handle_info(_Msg, S) -> {noreply, S}.

%% Drain every snapshot already queued and keep the last. Selective receive with
%% a zero timeout, so this is a mailbox scan and not a wait.
newest(Current, Skipped) ->
    receive
        {'$gen_cast', {snapshot, StoreId, Roster, Tally}} ->
            newest({StoreId, Roster, Tally}, Skipped + 1)
    after 0 -> {Current, Skipped}
    end.

write({StoreId, Roster, Tally}) -> roster_log:snapshot(StoreId, Roster, Tally).

written(ok, #{written := N} = S) -> S#{written := N + 1};
written({error, _Why}, #{failed := N} = S) -> S#{failed := N + 1}.
