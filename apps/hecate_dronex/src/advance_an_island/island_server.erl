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
%% ⚠⚠ THE ROSTER SURVIVES A RESTART AS OF ITEM 5, and it had to. A trained swarm
%% is expensive to produce and an island that lost it on every container recreate
%% would be a recording of its own first ten minutes. `roster_log' writes the
%% population down periodically and `init/1' reads it back BEFORE seeding, so a
%% restored lineage is never buried under fresh noise.
%%
%% FIVE TIMERS NOW, AND THEY ARE ON PURPOSE ALL DIFFERENT. The world advances at
%% its own pace, facts go out on wall clock, breeding runs when there is time, the
%% frozen exam is expensive and rare, and the roster is written down rarely. One
%% number could not serve any two of those.
-module(island_server).

-behaviour(gen_server).

-export([start_link/0, snapshot/0, island/0, publishes/0, roster/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

%% 20 Hz of simulated time per design/DESIGN_THE_AIRSPACE.md: one tick per 50 ms
%% of wall clock at these defaults. Nothing depends on the correspondence yet and
%% nothing should start to: the pace is how fast you watch, and the tick is what
%% the physics count.
-define(DEFAULT_TICKS_PER_SLOT, 10).
-define(DEFAULT_SLOT_MS, 500).
-define(DEFAULT_PUBLISH_MS, 1000).
%% One breeding round per second. A round is two evaluations of sixteen
%% engagements, so roughly a quarter of a second of work, which delays a publish
%% by less than the publish interval and never by more.
-define(DEFAULT_TRAIN_MS, 1000).
%% The frozen exam, every five minutes. It is 288 engagements and runs OFF this
%% process; see `handle_info(benchmark, ...)'.
-define(DEFAULT_BENCH_MS, 300000).
%% Write the roster down every two minutes.
-define(DEFAULT_SNAPSHOT_MS, 120000).
%% One watchable bout every twenty seconds. Frequent enough that a page is never
%% showing a fight from ten minutes ago, rare enough that a spectator on a slow
%% link is not perpetually downloading one.
-define(DEFAULT_BOUT_MS, 20000).

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

%% @doc This island's roster, for a script that wants to inspect the population.
-spec roster() -> roster:roster().
roster() -> gen_server:call(?MODULE, roster).

%%==============================================================================
%% gen_server
%%==============================================================================

%% ⚠ THE ROSTER IS RESTORED BEFORE ANYTHING IS SEEDED, and the order is the whole
%% point. Seeding first would bury a restored lineage under fresh noise, and the
%% only symptom would be an island that quietly starts again every time it is
%% recreated, which is precisely what persistence is here to prevent.
init([]) ->
    Island = island:seed_if_empty(restored(island:new(from_env()))),
    schedule(tick, slot_ms()),
    schedule(publish, publish_ms()),
    schedule(train, train_ms()),
    schedule(benchmark, ?DEFAULT_BENCH_MS),
    schedule(snapshot, ?DEFAULT_SNAPSHOT_MS),
    schedule(bout, ?DEFAULT_BOUT_MS),
    {ok, #{island => Island, sent => 0, failed => 0, sitting => false}}.

%% A store that is not there yet, or a log that cannot be read, is an island that
%% starts fresh rather than an island that refuses to start. The roster depth it
%% publishes is what makes that visible.
restored(Island) ->
    kept(Island, roster_log:restore(hecate_dronex_service:store_id(),
                                    island:roster_of(Island))).

kept(Island, {ok, R}) -> island:with_roster(Island, R);
kept(Island, {error, _Why}) -> Island.

handle_call(snapshot, _From, #{island := I} = S) ->
    {reply, dronex_facts:vitals(I), S};
handle_call(island, _From, #{island := I} = S) ->
    {reply, I, S};
handle_call(publishes, _From, #{sent := Sent, failed := Failed} = S) ->
    {reply, #{sent => Sent, failed => Failed}, S};
handle_call(roster, _From, #{island := I} = S) ->
    {reply, island:roster_of(I), S};
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
%% One breeding round, on this process. It is bounded work and the island has
%% nothing else to do between publishes.
handle_info(train, #{island := I} = S) ->
    schedule(train, train_ms()),
    {I2, _Report} = island:train(I),
    {noreply, S#{island := I2}};

%% ⚠ THE FROZEN EXAM RUNS OFF THIS PROCESS, AND IT HAS TO. It is 288 engagements,
%% a few seconds of work, and running it here would stop the island publishing
%% for that whole time. A reader cannot tell a paused island from a dead one.
%%
%% ⚠⚠ SPAWNED WITHOUT A LINK, DELIBERATELY. A benchmark that crashes must cost
%% one reading, not the island and its roster. Nothing arrives, `sitting' stays
%% true until the next timer, and the published profile is simply the previous
%% one, which is honest: it is the last exam actually sat.
handle_info(benchmark, #{island := I, sitting := false} = S) ->
    schedule(benchmark, ?DEFAULT_BENCH_MS),
    {noreply, S#{sitting := sit_off_process(I)}};
handle_info(benchmark, S) ->
    schedule(benchmark, ?DEFAULT_BENCH_MS),
    {noreply, S};
handle_info({benchmarked, Profile}, #{island := I} = S) ->
    {noreply, S#{island := island:benchmarked(I, Profile), sitting := false}};

%% ⚠ RUN INLINE AND WITH FRAMES ON, WHICH IS THE ONE PLACE THAT IS TRUE. An
%% engagement with the frame accumulator running allocates an arena per tick, so
%% every other caller leaves it off: a benchmark is 288 engagements and would
%% allocate 345,000 arenas to throw all but the last away. This is one
%% engagement every twenty seconds, and the frames are the entire point of it.
handle_info(bout, #{island := I} = S) ->
    schedule(bout, ?DEFAULT_BOUT_MS),
    {noreply, counted(publish_bout(I), S)};

handle_info(snapshot, #{island := I} = S) ->
    schedule(snapshot, ?DEFAULT_SNAPSHOT_MS),
    _ = roster_log:snapshot(hecate_dronex_service:store_id(), island:roster_of(I)),
    {noreply, S};

handle_info(_Msg, S) ->
    {noreply, S}.

%% @doc Fly the island's best controller against one of its drills, and publish
%% the recording.
%%
%% ⚠ THE DRILL ROTATES WITH THE CLOCK AND THE START DOES TOO, so a page left open
%% sees a different fight each time rather than the same one replayed. Derived
%% from the tick rather than drawn, because a bout must be reproducible from what
%% the fact already carries.
publish_bout(I) -> featured(roster:best(island:roster_of(I)), I).

featured(undefined, _I) -> {error, no_roster};
featured(Entry, I) ->
    Tick = island:tick_of(I),
    Kind = lists:nth((Tick div 20) rem length(drone_drills:kinds()) + 1,
                     drone_drills:kinds()),
    Index = Tick rem drone_starts:count(),
    flown(I, Entry, Kind, Index, engagement:controller(roster:entry_genome(Entry))).

flown(_I, _E, _K, _Ix, {error, _Why}) -> {error, unflyable};
flown(I, Entry, Kind, Index, {ok, Mine}) ->
    {ok, Theirs} = engagement:controller(Kind),
    Placed = drone_starts:place(1, 1, Index),
    [{AId, _, _, _, _, _}, {DId, _, _, _, _, _}] = Placed,
    Result = engagement:run(airspace:new(Placed),
                            #{AId => Mine, DId => Theirs}, #{frames => true}),
    Meta = #{kind => training, bout => island:tick_of(I), start_index => Index,
             entrants => [roster:entry_id(Entry), atom_to_binary(Kind, utf8)]},
    dronex_mesh:publish(dronex_facts:topic(bout),
                        dronex_facts:bout(I, Meta, Result,
                                          maps:get(frames, Result, []))).

%% The best entry sits the exam, because the exam asks what this island's drones
%% can do and the best is the honest answer to that.
sit_off_process(I) -> asked(roster:best(island:roster_of(I)), self()).

asked(undefined, _Back) -> false;
asked(Entry, Back) ->
    Genome = roster:entry_genome(Entry),
    _ = spawn(fun () -> Back ! {benchmarked, sat(benchmark:sit(Genome))} end),
    true.

sat({ok, Profile}) -> Profile;
sat({error, _Why}) -> benchmark:empty().

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
train_ms() -> positive_env("HECATE_DRONEX_TRAIN_MS", ?DEFAULT_TRAIN_MS).

positive_env(Name, Default) -> usable(os:getenv(Name), Default).

usable(false, Default) -> Default;
usable("", Default) -> Default;
usable(Str, Default) -> parsed(string:to_integer(string:trim(Str)), Default).

parsed({N, ""}, _Default) when N > 0 -> N;
parsed(_Unusable, Default) -> Default.
