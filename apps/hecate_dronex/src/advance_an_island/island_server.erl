%% @doc Owns this node's island and keeps it moving.
%%
%% TWO TIMERS, DELIBERATELY SEPARATE. The island advances on its own pace and
%% publishes on wall clock, because a world you WATCH and a world you SEARCH want
%% different rates, and a sibling spent several worlds discovering that one number
%% cannot serve both.
%%
%% ⚠ A DARK MESH IS NOT A FAILURE OF THE ISLAND. An island whose neighbours are
%% unreachable still breeds, still measures itself, and the only things lost are
%% that nobody hears about it and nobody attacks it. So a publish that cannot
%% happen is COUNTED and shrugged at, and `dronex_mesh' returns an error rather
%% than raising precisely so that this timer cannot kill the island.
%%
%% ⚠⚠ RESTARTING LOSES THE ISLAND, and that is honest at item 1 rather than an
%% oversight. The store is open and nothing writes to it. It stops being
%% acceptable at item 5, where the roster arrives: a trained swarm is expensive to
%% produce, and an island that loses it on every container recreate is a recording
%% of its own first ten minutes.
-module(island_server).

-behaviour(gen_server).

-export([start_link/0, snapshot/0, island/0, publishes/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

%% 20 Hz of simulated time per design/DESIGN_THE_AIRSPACE.md: one tick per 50 ms
%% of wall clock at these defaults. Nothing depends on the correspondence yet and
%% nothing should start to: the pace is how fast you watch, and the tick is what
%% the physics count.
-define(DEFAULT_TICKS_PER_SLOT, 10).
-define(DEFAULT_SLOT_MS, 500).
-define(DEFAULT_PUBLISH_MS, 1000).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc The published shape, without needing a mesh. What a local page would draw.
-spec snapshot() -> map().
snapshot() -> gen_server:call(?MODULE, snapshot).

%% @doc The island itself, for a script that wants to measure rather than watch.
-spec island() -> island:island().
island() -> gen_server:call(?MODULE, island).

%% @doc How many facts went out, and how many could not.
-spec publishes() -> #{sent := non_neg_integer(), failed := non_neg_integer()}.
publishes() -> gen_server:call(?MODULE, publishes).

%%==============================================================================
%% gen_server
%%==============================================================================

init([]) ->
    Island = island:new(from_env()),
    schedule(tick, slot_ms()),
    schedule(publish, publish_ms()),
    {ok, #{island => Island, sent => 0, failed => 0}}.

handle_call(snapshot, _From, #{island := I} = S) ->
    {reply, dronex_facts:vitals(I), S};
handle_call(island, _From, #{island := I} = S) ->
    {reply, I, S};
handle_call(publishes, _From, #{sent := Sent, failed := Failed} = S) ->
    {reply, #{sent => Sent, failed => Failed}, S};
handle_call(_Other, _From, S) ->
    {reply, {error, unknown_call}, S}.

handle_cast(_Msg, S) -> {noreply, S}.

handle_info(tick, #{island := I} = S) ->
    schedule(tick, slot_ms()),
    {noreply, S#{island := island:run(I, ticks_per_slot())}};
handle_info(publish, #{island := I} = S) ->
    schedule(publish, publish_ms()),
    {noreply, counted(dronex_mesh:publish(dronex_facts:topic(vitals),
                                          dronex_facts:vitals(I)), S)};
handle_info(_Msg, S) ->
    {noreply, S}.

%% ⚠ COUNTED RATHER THAN LOGGED. CHARTER.md rule 4: a capacity that was never
%% exercised is not evidence of anything, so the exercise count is available
%% beside every null. An island that has published nothing and an island whose
%% every publish failed look identical in a log and are different questions.
counted(ok, #{sent := N} = S) -> S#{sent := N + 1};
counted({error, _Why}, #{failed := N} = S) -> S#{failed := N + 1}.

schedule(Msg, Ms) -> erlang:send_after(Ms, self(), Msg).

%%==============================================================================
%% Configuration
%%==============================================================================

%% ⚠ A NODE CONFIG MAY NAME WHAT A NODE IS AND NEVER WHAT THE PHYSICS ARE.
%% CHARTER.md rule 2, and it cost a sibling a two-hour boot-crash loop.
%%
%% So: the seed and the pace come from the environment, because they say which
%% RUN this is and how fast to watch it. The flight model, the battery economy,
%% the sensor channels and the sensor coverage do not, because they are the
%% physics and they ship with the image or they are not physics.
from_env() ->
    maps:merge(#{}, seeded(os:getenv("HECATE_DRONEX_SEED"))).

seeded(false) -> #{};
seeded("") -> #{};
seeded(Str) -> seed_of(string:to_integer(string:trim(Str))).

%% A malformed seed is no seed rather than a crash, for the same reason the pace
%% variables fall back: a typo in a deployment file should cost the default, not
%% the island.
seed_of({N, ""}) -> #{seed => N};
seed_of(_Unusable) -> #{}.

ticks_per_slot() -> positive_env("HECATE_DRONEX_TICKS_PER_SLOT", ?DEFAULT_TICKS_PER_SLOT).
slot_ms() -> positive_env("HECATE_DRONEX_SLOT_MS", ?DEFAULT_SLOT_MS).
publish_ms() -> positive_env("HECATE_DRONEX_PUBLISH_MS", ?DEFAULT_PUBLISH_MS).

positive_env(Name, Default) -> usable(os:getenv(Name), Default).

usable(false, Default) -> Default;
usable("", Default) -> Default;
usable(Str, Default) -> parsed(string:to_integer(string:trim(Str)), Default).

parsed({N, ""}, _Default) when N > 0 -> N;
parsed(_Unusable, Default) -> Default.
