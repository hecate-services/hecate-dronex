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

%% ⚠ THE ABLATION IS FOUR TIMES THE COST OF THE FIGHTS IT MEASURES, which is why
%% it has its own slow clock rather than riding the bout timer. Twelve swarm
%% engagements run four ways is forty-eight, against the benchmark's 288, and
%% both run off-process on a four-core Celeron.
-define(DEFAULT_ABLATE_MS, 300000).

%% ⚠ SLOW, AND SLOWER THAN IT LOOKS. A raid costs the DEFENDER an engagement and
%% costs both sides airframes that have to be bred back. An island raiding every
%% few seconds would spend its whole life rebuilding, which is the stasis this
%% design is most at risk of: islands raiding, losing, rebuilding and raiding
%% again while nothing selects.
-define(DEFAULT_RAID_MS, 120000).

%% ⚠ THE LEASE, AND ITS LENGTH IS THE DESIGN DECISION. Announced every 30s while
%% open, believed for five minutes. Short enough that a dead island stops being
%% raided within one raid interval; long enough that OPEN is the resting state,
%% because a lease that lapses easily makes neglect safe and islands drift into
%% turtling — the failure the roster design names as the one it is most at risk
%% of. Staying open is what happens if you do nothing; closing is an act.
-define(ANNOUNCE_MS, 30000).
-define(OPEN_FOR_MS, 300000).

%% ⚠ LONGER THAN ANY HONEST ENGAGEMENT AND SHORTER THAN A RAID INTERVAL. A
%% defender validates, musters, fights up to 1200 ticks and publishes; measured,
%% a six-against-six is a fraction of a second. Five minutes is generous enough
%% that a slow node is never punished, and short enough that an island is not
%% still holding parties out when its next raid comes round.
-define(SETTLE_BY_MS, 300000).
-define(SWEEP_MS, 60000).

%% Often enough that a mesh coming up late costs a minute rather than a
%% deployment, rare enough that re-asserting is not chatter.
-define(DEFAULT_MESH_CHECK_MS, 60000).

%% ⚠ SWARM, NOT DUEL, AND A DUEL WOULD HAVE MADE THE MEASUREMENT MEANINGLESS. In
%% a one-against-one fight there is no friendly to talk to, so the friendly bank
%% is structurally zero and muting it cannot change anything. An ablation run on
%% duels would report `comms do not matter' with perfect consistency, and it
%% would be an artefact of the formation rather than a finding about the channel.
-define(ABLATE_PER_SIDE, 3).
-define(ABLATE_STARTS, 4).

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
    %% Offset from the benchmark's first firing so the two heavy jobs do not
    %% start together on a node with four slow cores.
    schedule(ablate, ?DEFAULT_ABLATE_MS div 2),
    schedule(raid, ?DEFAULT_RAID_MS),
    %% ⚠⚠ ON A TIMER, AND THE FIRST VERSION DID IT ONCE HERE AND CLAIMED
    %% OTHERWISE. Its comment said "the retry is the next timer tick"; there was
    %% no such tick. `init/1' runs before `hecate_om_identity' can answer, so
    %% `dronex_mesh:advertise/2' failed on the fleet realm, the pool never
    %% learned the handler, and the island advertised nothing for the rest of its
    %% life.
    %%
    %% ⚠⚠⚠ AND THE FAILURE WAS INVISIBLE FROM EVERY ANGLE. The STATION still held
    %% a route from an earlier incarnation, pointing at a connection that was
    %% still alive, so a caller's CALL was forwarded and simply never answered:
    %% it timed out after two minutes with `vanished into the dark'. Meanwhile
    %% SUBSCRIBING worked, because it uses the public realm out of an environment
    %% variable and never asks `hecate_om' for anything — so the island heard its
    %% neighbours, raided them enthusiastically, and could not be raided back.
    %% Twelve raids launched, one ever hosted, and `/health' green throughout.
    %%
    %% Re-asserted every tick rather than once-until-it-works, because a pool
    %% restart, a link respawn or a stale station entry all heal the same way and
    %% none of them tells us they happened. Advertising the same procedure twice
    %% is a map overwrite at the pool and a re-register at the station.
    schedule(mesh_check, 0),
    schedule(announce, ?ANNOUNCE_MS),
    schedule(sweep_raids, ?SWEEP_MS),
    {ok, #{island => Island, sent => 0, failed => 0, sitting => false,
           ablating => false, writer => roster_log_writer:silent(),
           open_islands => #{}, away => #{},
           advertising => false, open => false}}.

%% ⚠ ADDRESSED BY IDENTITY, NEVER BY NAME. Two islands may both be called
%% `beam02'; only the 128 bits in the data directory are unique. A procedure
%% named after the nickname would send a raid to whichever of them advertised
%% last.
advertise_self() ->
    Self = self(),
    dronex_mesh:advertise(dronex_raid:procedure(dronex_identity:island_id()),
                          fun (Request) -> host_a_raid(Request, Self) end).

%% ⚠ AVAILABILITY, NOT PRESENCE. This used to subscribe to `vitals' — thirty
%% fields including a benchmark ladder, once a second, from every island — to
%% read one thing: who exists. What an island actually needs is who can be
%% FOUGHT, which is a smaller fact and a different question. Presence stays on
%% `vitals' for the site, which needs the islands that are closed too.
%% ⚠⚠ ONE SUBSCRIPTION PER TOPIC, TRACKED BY TOPIC, AND THE FIRST VERSION DID NOT
%% DO THAT. It subscribed to all three whenever it thought it was not listening,
%% and `{macula_event_gone, Ref, _}' for ANY ONE of them set that flag false. So
%% one dead subscription produced three new ones while the two live siblings
%% stayed live, the next death produced three more, and every fact was delivered
%% once per surviving subscription.
%%
%% Measured on beam02 before the fix: **615,722 messages in the island's
%% mailbox**, the process wedged inside `macula_client:subscribe' making it
%% worse, `gen_server:call(island_server, snapshot, 30000)' timing out, 26 failed
%% publishes, and — the part that looked like a different bug entirely — raids
%% stuck `in flight' on the public page because the settlements were somewhere in
%% that queue. One fault, five symptoms.
%%
%% The comment above it already said every `subscribe' returns a fresh reference
%% and the pool keeps them all. It guarded the TIMER against multiplying them and
%% left the death path to do it instead.
%% ⚠ THIS PROCESS NO LONGER OWNS THE SUBSCRIPTIONS. It owned all three and
%% re-armed the set whenever any one died, which bred 615,722 messages into its
%% own mailbox. `topic_listener' is one process per topic; each holds a single
%% reference and cannot name another. The island is told what arrived.
topics_heard() -> [opened, closed, settled].

%% Re-asserted every tick. The transition is logged, so a mesh that comes up late
%% says so once rather than every minute for ever.
advertising(S) -> announced(advertise_self(), maps:get(advertising, S), S).

announced(ok, false, S) ->
    logger:info("[island] advertised for raids as ~s",
                [dronex_raid:procedure(dronex_identity:island_id())]),
    S#{advertising := true};
announced(ok, true, S) ->
    S;
announced({error, Why}, true, S) ->
    logger:warning("[island] can no longer advertise for raids: ~s", [terse(Why)]),
    S#{advertising := false};
announced({error, _Why}, false, S) ->
    S.

%% ⚠ ONLY THE TOPICS THAT ARE NOT ALREADY SUBSCRIBED. Every `subscribe' returns a
%% fresh reference and the pool keeps them all, so subscribing to something twice
%% doubles its delivery rate for ever, and nothing anywhere reports it.
%% Asked of the listeners rather than remembered here, because a copy of somebody
%% else's state is a thing that can disagree with it — which is how the
%% subscription bug survived its own first fix.
listening() -> lists:all(fun topic_listener:listening/1, topics_heard()).

%% A store that is not there yet, or a log that cannot be read, is an island that
%% starts fresh rather than an island that refuses to start. The roster depth it
%% publishes is what makes that visible.
restored(Island) ->
    kept(Island, roster_log:restore(hecate_dronex_service:store_id(),
                                    island:roster_of(Island))).

%% The roster AND the tally, because a lineage is what it bred and what it did.
kept(Island, {ok, R, Tally}) -> island:with_tally(island:with_roster(Island, R), Tally);
%% ⚠⚠ LOUD, AND IT WAS SILENT FOR THE WHOLE LIFE OF THE MODULE. This clause used
%% to be `kept(Island, {error, _Why}) -> Island', which is the correct BEHAVIOUR
%% (an island that cannot read its log must still start) attached to the wrong
%% REPORTING (nobody was told). `roster_log:restore/2' raised `badmap' on the
%% first event of every restore it ever attempted, every island began again from
%% seed on every deploy, and the only published evidence, roster depth, reads the
%% same for a restored lineage and for a fresh one filling up. Discovered
%% 2026-08-07 by measuring, not by reading a log, because there was none.
kept(Island, {error, Why}) ->
    logger:error("ROSTER NOT RESTORED, THIS ISLAND IS STARTING FROM SEED: ~0p", [Why]),
    Island.

handle_call(snapshot, _From, #{island := I} = S) ->
    {reply, dronex_facts:vitals(I, runtime(S)), S};
handle_call(island, _From, #{island := I} = S) ->
    {reply, I, S};
handle_call(publishes, _From, #{sent := Sent, failed := Failed} = S) ->
    {reply, #{sent => Sent, failed => Failed}, S};
handle_call(roster, _From, #{island := I} = S) ->
    {reply, island:roster_of(I), S};
%% ⚠ FAST, AND THE ONLY PART OF BEING RAIDED THAT TOUCHES THIS PROCESS. It takes
%% the defending party out of the roster and returns. The engagement runs in
%% macula's process, so the island keeps ticking, breeding and publishing while
%% it is under attack — which is what lets a popular island stay alive while it
%% is being ground down by attention.
%%
%% ⚠⚠ THE DEFENDER PAYS ON THE SAME TERMS, INCLUDING THE FLOOR. `island:muster/2'
%% refuses below it, so an island that has been raided to the floor cannot field
%% a defence and REFUSES. That is not a shield: refusing means it stops gaining
%% the attacker's genomes, which is the only thing being raided is good for.
handle_call({defend, Req}, _From, #{island := I} = S) ->
    mustered_defence(island:muster(I, length(maps:get(sortie, Req))), S);
handle_call(_Other, _From, S) ->
    {reply, {error, unknown_call}, S}.

mustered_defence({_I, []}, S) ->
    {reply, {error, below_the_floor}, S};
mustered_defence({I2, Party}, #{island := I} = S) ->
    %% The start geometry is derived from the tick rather than drawn, so a raid
    %% is reproducible from the facts it publishes.
    Index = island:tick_of(I) rem drone_starts:count(),
    %% ⚠ THE ROSTER STAMP RIDES BACK ON A CALL THAT WAS ALREADY HAPPENING. The
    %% raid recording needs to say where this island was in its own evolution,
    %% and the recording is built OFF this process on purpose — it is ~1.6 MB of
    %% frames, and casting it here to read two integers would put the whole
    %% engagement through the island's mailbox and stop its clock to announce
    %% something it already knows. Three integers on a reply, no new message.
    Stamp = #{generation => island:generation_of(I2), rounds => island:rounds_of(I2)},
    {reply, {ok, Party, Index, Stamp}, S#{island := I2}}.

%% The writer's own exercise counts, pushed after every drain. Held rather than
%% fetched: see `roster_log_writer:told/1'.
%% What a `topic_listener' heard. The island does not care which topic it came
%% from: `noted/2' decides from the shape, because the shape is what says whether
%% a fact is an opening, a closing or a settlement.
handle_cast({heard, Fact}, S) -> {noreply, noted(Fact, S)};
handle_cast({roster_written, Stats}, S) -> {noreply, S#{writer := Stats}};
%% A fact published from somebody else's process still belongs in this island's
%% counters, or `sent' and `failed' quietly stop describing everything it sends.
handle_cast({published, Outcome}, S) -> {noreply, counted(Outcome, S)};
%% ⚠ THE COMMITMENT IS BUILT HERE AND PUBLISHED FROM HERE, because it now carries
%% the committing island's own roster state and only this process holds the
%% island. Both sides announce: the attacker from `away/4' off-process, the
%% defender from macula's process while hosting, and neither of them has the
%% island in hand. Building the fact where the state is costs one cast and is the
%% only place the numbers are true.
handle_cast({commit_as, Role, RaidId, Opponent, Airframes}, #{island := I} = S) ->
    {noreply, counted(commit(RaidId, Role, {Opponent, Airframes}, I), S)};
%% A raid this island hosted has finished, off-process. Two things settle at
%% once: the defenders that survived come back, and the attacker's genomes are
%% kept whatever the outcome was.
handle_cast({defended, Survivors, Party, Raiders, Meta}, #{island := I} = S) ->
    {noreply, S#{island := island:defended(I, Survivors, Party, Raiders, Meta)}};
%% A raid this island sent has come home, or has failed to.
%% The handshake answered. Accepted means the party is committed and waits for a
%% settlement fact; refused means it never engaged and comes straight home.
handle_cast({handshook, RaidId, Party, accepted}, #{away := A} = S) ->
    {noreply, S#{away := A#{RaidId => {erlang:monotonic_time(millisecond), Party}}}};
handle_cast({handshook, RaidId, Party, refused}, #{island := I, away := A} = S) ->
    {noreply, S#{island := island:returned(I, Party, #{fates => refused}),
                 away := maps:remove(RaidId, A)}};
handle_cast(_Msg, S) -> {noreply, S}.

handle_info(tick, #{island := I} = S) ->
    schedule(tick, slot_ms()),
    {noreply, S#{island := island:run(I, ticks_per_slot())}};
handle_info(publish, #{island := I} = S) ->
    schedule(publish, publish_ms()),
    {noreply, counted(dronex_mesh:publish(dronex_facts:topic(vitals),
                                          dronex_facts:vitals(I, runtime(S))), S)};
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
handle_info({benchmarked, Profile, Trials, Origin}, #{island := I} = S) ->
    {noreply, S#{island := island:benchmarked(I, Profile, Trials, Origin),
                 sitting := false}};

%% ⚠ RUN INLINE AND WITH FRAMES ON, WHICH IS THE ONE PLACE THAT IS TRUE. An
%% engagement with the frame accumulator running allocates an arena per tick, so
%% every other caller leaves it off: a benchmark is 288 engagements and would
%% allocate 345,000 arenas to throw all but the last away. This is one
%% engagement every twenty seconds, and the frames are the entire point of it.
handle_info(bout, #{island := I} = S) ->
    schedule(bout, ?DEFAULT_BOUT_MS),
    {noreply, counted(publish_bout(I), S)};

%% ⚠ SPAWNED WITHOUT A LINK, for the same reason the benchmark is: an instrument
%% that crashes must cost the island a stale reading, never its life. The
%% previously published report simply stands, and the exercise count beside it
%% stops rising, which is what makes the staleness visible.
handle_info(ablate, #{island := I, ablating := false} = S) ->
    schedule(ablate, ?DEFAULT_ABLATE_MS),
    {noreply, S#{ablating := ablate_off_process(I)}};
handle_info(ablate, S) ->
    schedule(ablate, ?DEFAULT_ABLATE_MS),
    {noreply, S};
handle_info({ablated, Report}, #{island := I} = S) ->
    {noreply, S#{island := island:ablated(I, Report), ablating := false}};

%% ⚠ A CAST TO THE WRITER, NEVER THE WRITE ITSELF, AND THIS LINE WEDGED THE FIRST
%% DEPLOYED ISLAND FOR FOUR MINUTES. It called `roster_log:snapshot/2' directly.
%% The stream id was invalid, the store's rejection arrived as an exit rather
%% than an error, and reckon-gater retried it eleven times with exponential
%% backoff — all of it on this process. The clock stopped, nothing published,
%% `/health' answered `ok' the whole time and the container stayed `healthy'.
%%
%% The stream id is fixed. This is the part that makes the next store problem
%% cost staleness rather than the island. See `roster_log_writer'.
handle_info(snapshot, #{island := I} = S) ->
    schedule(snapshot, ?DEFAULT_SNAPSHOT_MS),
    roster_log_writer:snapshot(hecate_dronex_service:store_id(),
                               island:roster_of(I), island:tally_of(I)),
    {noreply, S};

%% ⚠ FIVE ELEMENTS. A four-element clause here would match nothing, every fact
%% would fall through to the catch-all, and this island would believe it is alone
%% in the archipelago while its subscription sat there perfectly healthy. A
%% sibling shipped exactly that and it cost an hour.
%% ⚠ RE-ARM ONLY THE ONE THAT DIED. Dropping the dead reference and letting
%% `listening/1' fill the gap replaces exactly one subscription; the previous
%% version cleared a single boolean and re-subscribed all three, which is what
%% multiplied them.
%% ⚠ THE ONE THING THAT MAKES THIS ISLAND REACHABLE. Everything else it does is
%% outbound and works without anybody's permission; being raided needs a live
%% advertisement, and an advertisement is the only piece of this service that can
%% be lost without anything going red.
handle_info(mesh_check, S) ->
    schedule(mesh_check, ?DEFAULT_MESH_CHECK_MS),
    {noreply, advertising(S)};

%% ⚠ THE ONLY THING THAT WRITES A PARTY OFF NOW. With the outcome arriving as a
%% fact rather than as a return value, nothing fails: a settlement that never
%% comes is silence, and silence needs a clock. The party left the roster when it
%% was mustered, so this is where the cost of raiding into the dark is finally
%% paid — deliberately, by a timer this island owns, rather than inherited from
%% somebody else's transport error.
handle_info(sweep_raids, #{island := I, away := A} = S) ->
    schedule(sweep_raids, ?SWEEP_MS),
    Now = erlang:monotonic_time(millisecond),
    Late = [{R, P} || {R, {At, P}} <- maps:to_list(A), Now - At > ?SETTLE_BY_MS],
    {noreply, S#{island := written_off(Late, I), away := maps:without([R || {R, _} <- Late], A)}};

handle_info(announce, S) ->
    schedule(announce, ?ANNOUNCE_MS),
    {noreply, handle_announcement(S)};

handle_info(raid, #{island := I} = S) ->
    schedule(raid, ?DEFAULT_RAID_MS),
    {noreply, launched(I, S)};

handle_info(_Msg, S) ->
    {noreply, S}.

written_off([], I) -> I;
written_off([{RaidId, Party} | Rest], I) ->
    logger:warning("[island] raid ~s never settled, party written off", [RaidId]),
    written_off(Rest, island:returned(I, Party, #{fates => []})).

%% What the server knows about itself, as opposed to what the island knows about
%% its world. Kept in one place so a new field is one line rather than three.
%% `listening' is derived rather than stored: it is true when every topic an
%% island needs is subscribed, which is the only definition that cannot drift
%% from the subscriptions themselves.
runtime(S) -> (maps:with([writer, advertising, open], S))#{listening => listening()}.

%% ⚠ AN ISLAND ANNOUNCES OPEN ONLY WHEN IT ACTUALLY IS, AND THAT IS THE POINT.
%% `advertising' is whether the raid procedure is really registered; without that
%% check an island could announce itself open, be believed, and answer nothing —
%% which is precisely I.11, where it was busy, healthy, and unreachable for
%% hours. The published state is DERIVED from the capability rather than asserted
%% beside it, so it cannot lie.
%%
%% ⚠⚠ AND ABOVE THE FLOOR, because an island that cannot muster a defence will
%% refuse anyway. Announcing open while unable to field anybody would spend a
%% neighbour's whole raiding party to discover it.
%%
%% The POLICY is `open whenever capable', stated rather than implied, and it is
%% deliberately the simplest one for the same reason raid initiation is: a clever
%% policy would be a tactic nobody evolved. It is the seam where a real one goes.
handle_announcement(#{island := I} = S) ->
    Now = capable(S) andalso island:can_defend(I, raid:party()),
    announced_state(Now, maps:get(open, S), I, S#{open := Now}).

capable(#{advertising := A}) -> A andalso listening().

%% Re-announced while open, because it is a lease. Announced once on the way
%% down, because closing should cost seconds rather than the lease.
announced_state(true, _Was, I, S) ->
    counted(dronex_mesh:publish_between_islands(dronex_facts:topic(opened),
                                                dronex_facts:opened(I)), S);
announced_state(false, true, _I, S) ->
    logger:info("[island] closed for battle"),
    counted(dronex_mesh:publish_between_islands(dronex_facts:topic(closed),
                                                dronex_facts:closed()), S);
announced_state(false, false, _I, S) ->
    S.

%% Who else can be fought, and when they last said so. Anything that is not a
%% vitals fact from somebody else is ignored rather than guessed at.
%% A settlement names a raid this island may have out. Matched on `raid_id'
%% rather than on who sent it, because the id is what the attacker issued and is
%% the only thing that ties a fact to a party.
noted(#{raid_id := RaidId, fate := Fates}, #{island := I, away := A} = S)
  when is_binary(RaidId), is_list(Fates) ->
    home(maps:take(RaidId, A), Fates, I, S);
%% An `opened' carries what a caller needs to skip a pointless raid; a `closed'
%% carries only who. Anything else is ignored rather than guessed at.
noted(#{island_id := Id, fingerprint := F, roster := R}, S) when is_binary(Id) ->
    opened_by(Id =:= dronex_identity:island_id(), Id, #{fingerprint => F, roster => R}, S);
noted(#{island_id := Id}, #{open_islands := O} = S) when is_binary(Id) ->
    S#{open_islands := maps:remove(Id, O)};
noted(_Other, S) ->
    S.

%% ⚠ A SETTLEMENT FOR A RAID THIS ISLAND DOES NOT HAVE OUT IS IGNORED, NOT
%% GUESSED AT. Every island on the fleet realm hears every settlement, so most of
%% them are somebody else's; and a duplicate for a party already settled must not
%% re-admit genomes that have since been evicted or bred over.
home(error, _Fates, _I, S) ->
    S;
home({Party, A}, Fates, I, S) ->
    Settled = #{fates => [{Id, F} || #{id := Id, fate := F} <- Fates]},
    S#{island := island:returned(I, element(2, Party), Settled), away := A}.

opened_by(true, _Id, _Meta, S) -> S;
opened_by(false, Id, Meta, #{open_islands := O} = S) ->
    S#{open_islands := O#{Id => {erlang:monotonic_time(millisecond), Meta}}}.

%% ⚠ FILTERED HERE RATHER THAN DISCOVERED BY REFUSAL. An island whose engine
%% differs would refuse the raid on arrival and an island at its floor would have
%% nobody to field, and both cost a whole party to find out. The lease expiry is
%% what makes a dead island stop being a target.
targets(#{open_islands := O}) ->
    Now = erlang:monotonic_time(millisecond),
    Mine = dronex_raid:fingerprint(),
    [Id || {Id, {At, #{fingerprint := F, roster := R}}} <- maps:to_list(O),
           Now - At =< ?OPEN_FOR_MS,
           F =:= Mine,
           R > raid:floor_of()].

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
    %% A training bout is flown at home like every other training fight, so the
    %% exhibit shows the island's towers standing in its own airspace.
    Result = engagement:run(airspace:new(Placed), #{AId => Mine, DId => Theirs},
                            #{frames => true, network => ground_network:home()}),
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
    %% ⚠ THE WHOLE SITTER TRAVELS WITH THE SCORE. Read here rather than later,
    %% because by the time the profile comes back the roster has bred on and
    %% `best' may be a different entry — the answer would be about whoever is
    %% champion NOW and not about whoever actually sat it.
    %%
    %% ⚠⚠ AND IT IS THE IDENTITY, NOT ONLY THE PROVENANCE FLAG. A genome id is
    %% the sha256 of its packed form, so the SAME id appearing as champion on two
    %% islands is a controller that crossed the mesh — which is the archipelago's
    %% entire claim and was, until now, publishable only as a count going up.
    Sitter = #{id => roster:entry_id(Entry),
               generation => roster:entry_generation(Entry),
               sorties => roster:entry_sorties(Entry),
               origin => roster:entry_origin(Entry)},
    %% ⚠ BOTH LADDERS IN ONE SPAWN, BY THE SAME GENOME. The curriculum profile
    %% and the held-out profile are only comparable if one controller sat both,
    %% and `roster:best/1' changes every few seconds. Two spawns would have
    %% produced two readings of two different champions labelled as one.
    %%
    %% ⚠⚠ AND IT DOUBLES THE WORK OF A SITTING, WHICH IS MEASURED RATHER THAN
    %% ASSUMED AFFORDABLE. Six rungs over 48 starts is 288 engagements; two
    %% ladders is 576, once every five minutes, off-process, behind the `sitting'
    %% guard that stops a slow sitting from overlapping the next one.
    %%
    %% Timed on the fleet's WEAKEST champion, which is the expensive case because
    %% a controller that cannot finish a fight runs it to the battery: 4.6 s for
    %% the curriculum and 8.5 s for the held-out ladder on a development machine.
    %% A Celeron J4105 is several times slower, so a bad sitting is minutes rather
    %% than seconds and may occasionally skip its next slot. That is what the
    %% guard is for, and a skipped sitting is a gap in a five-minute series rather
    %% than a starved trainer, because this runs in its own process.
    _ = spawn(fun () ->
                      Back ! {benchmarked,
                              sat(benchmark:sit(Genome),
                                  benchmark:curriculum_ladder()),
                              sat(benchmark:sit(Genome,
                                                #{ladder => benchmark:held_out_ladder()}),
                                  benchmark:held_out_ladder()),
                              Sitter}
              end),
    true.

%% ⚠ AN EMPTY PROFILE OF THE RIGHT LADDER, so a genome the exam refused still
%% publishes the rung NAMES a reader needs to tell the two exams apart. Falling
%% back to `benchmark:empty/0' here would have published the curriculum's rung
%% names beside the held-out exam's zeros.
sat({ok, Profile}, _Ladder) -> Profile;
sat({error, _Why}, Ladder) -> benchmark:empty(Ladder).

%% @doc Ask whether this island's own controllers are using the channel.
%%
%% ⚠ SELF-PLAY, NOT THE LADDER, AND THAT IS FORCED RATHER THAN CHOSEN. The drills
%% are scripted and never transmit, so an ablation against them is void by
%% construction: see `ablation_tests'. The only fights on this island where
%% anything is said are the ones its own controllers fly against each other.
ablate_off_process(I) -> ablating(roster:best(island:roster_of(I)), I, self()).

ablating(undefined, _I, _Back) -> false;
ablating(Best, I, Back) ->
    Fights = swarm_fights(Best, opponent_of(I, Best), island:tick_of(I)),
    _ = spawn(fun () -> Back ! {ablated, ablation:measure(Fights)} end),
    true.

%% The best against the worst that is not itself, so the pair is deterministic
%% from the roster rather than drawn, and reproducible from the published tick.
opponent_of(I, Best) ->
    Others = [E || E <- roster:entries(island:roster_of(I)),
                   roster:entry_id(E) =/= roster:entry_id(Best)],
    first_or(Others, Best).

first_or([E | _], _Fallback) -> E;
first_or([], Fallback) -> Fallback.

%% ⚠ ONE GENOME PER SIDE, FLOWN BY EVERY DRONE ON IT. The population is
%% homogeneous by design: a sum-not-slot radio is invariant to swarm size
%% precisely so that one controller flies as three or as twelve without per-slot
%% specialists, and a heterogeneous swarm here would fold `which genome' into a
%% number that is supposed to be about `which channel'.
swarm_fights(Mine, Theirs, Tick) ->
    Starts = [(Tick + N) rem drone_starts:count() || N <- lists:seq(0, ?ABLATE_STARTS - 1)],
    lists:filtermap(fun (Ix) -> composed(Mine, Theirs, Ix) end, Starts).

composed(Mine, Theirs, Index) ->
    Placed = drone_starts:place(?ABLATE_PER_SIDE, ?ABLATE_PER_SIDE, Index),
    manned(Placed, roster:entry_genome(Mine), roster:entry_genome(Theirs)).

%% A genome that will not fly is dropped rather than scored, exactly as the
%% trainer refuses one rather than giving it a zero: a dropped fight lowers the
%% exercise count, and a zero would silently move the delta.
manned(Placed, A, D) -> crewed(Placed, A, D, engagement:controller(A),
                               engagement:controller(D)).

crewed(_Placed, _A, _D, {error, _Why}, _Theirs) -> false;
crewed(_Placed, _A, _D, _Mine, {error, _Why}) -> false;
crewed(Placed, A, D, {ok, _}, {ok, _}) ->
    %% ⚠ A FRESH CONTROLLER PER DRONE, NOT ONE SHARED. A pilot carries the
    %% network's recurrent state, so handing the same one to three drones would
    %% have them share a memory and the swarm would behave as one animal.
    Cs = maps:from_list([{Id, fresh(Side, A, D)} || {Id, Side, _, _, _, _} <- Placed]),
    {true, {airspace:new(Placed), Cs}}.

fresh(attacker, A, _D) -> element(2, engagement:controller(A));
fresh(defender, _A, D) -> element(2, engagement:controller(D)).

%%==============================================================================
%% Raiding somebody
%%==============================================================================

%% ⚠ THE PARTY LEAVES ON THIS PROCESS AND THE CALL DOES NOT. Taking genomes out
%% of the roster must be atomic with deciding to go, or two timers could send the
%% same genome twice. The CALL then blocks for up to two minutes while the
%% defender fights, and doing that here would stop the clock, the trainer and the
%% publisher for the whole engagement — which is exactly how the first deployed
%% island wedged itself on a store write.
%% ⚠ THE ISLAND COMES BACK EVEN WHEN NOTHING IS AIMED AT, because choosing is a
%% DRAW and the generator advanced. Dropping the returned island on the `none'
%% path would replay the same draw next tick for as long as the archipelago
%% stayed empty.
launched(I, S) ->
    aimed(island:aim(I, targets(S), dronex_identity:island_id()), S).

aimed({I2, none}, S) -> S#{island := I2};
aimed({I2, {ok, Target}}, S) -> mustered(island:muster(I2, raid:party()), Target, S).

%% Below the floor, or nothing to send: stay home and breed. The floor is what
%% stops an island raiding itself to extinction.
mustered({_I, []}, _Target, S) -> S;
mustered({I2, Party}, Target, S) ->
    RaidId = new_raid_id(),
    Back = self(),
    _ = spawn(fun () -> away(Target, RaidId, Party, Back) end),
    %% Not recorded as outstanding until the handshake says accepted: a raid
    %% nobody took must not sit in the sweep waiting to be written off.
    S#{island := I2}.

%% Off-process, start to finish: compose the request, make the call, and cast the
%% settlement back. Nothing here touches the island's state.
away(Target, RaidId, Party, Back) ->
    Sorties = [#{id => roster:entry_id(E),
                 genome => drone_genome:pack(roster:entry_genome(E))} || E <- Party],
    Request = dronex_raid:request(dronex_identity:island_id(), RaidId, Sorties, 0),
    Reply = dronex_mesh:call(dronex_raid:procedure(Target), Request,
                             dronex_raid:call_timeout_ms()),
    Answer = accepted(RaidId, Target, Reply),
    _ = announce_commitment(Answer, RaidId, Target, length(Party), Back),
    gen_server:cast(Back, {handshook, RaidId, Party, Answer}).

%% Only when the raid was actually taken. A refused party never left the ground,
%% so announcing a commitment for it would be announcing a cost nobody paid.
announce_commitment(accepted, RaidId, Target, Airframes, Back) ->
    gen_server:cast(Back, {commit_as, attacker, RaidId, Target, Airframes});
announce_commitment(refused, _RaidId, _Target, _Airframes, _Back) ->
    ok.

%% ⚠ ONLY TWO ANSWERS NOW, AND NEITHER OF THEM IS AN OUTCOME. Accepted means the
%% party is committed and the result will arrive as a fact. Anything else means
%% it never engaged, so it never left the ground.
accepted(RaidId, _Target, {ok, Reply}) -> decoded(RaidId, dronex_raid:decode_reply(Reply));
accepted(RaidId, Target, {error, Why}) ->
    logger:warning("[island] raid ~s on ~s was not accepted: ~s",
                   [RaidId, Target, terse(Why)]),
    refused.

decoded(_RaidId, {ok, _Accepted}) -> accepted;
%% ⚠⚠ A REFUSAL IS NOT A LOSS, AND THE DIFFERENCE IS WHETHER ANYBODY ANSWERED.
%% An explicit refusal — mismatched engine, bad genome, a defender at its floor —
%% means the engagement never started. Charging for it would price a protocol
%% disagreement the same as a massacre, and an island on a stale build would
%% bleed its whole roster into neighbours that kept politely saying no.
decoded(RaidId, {error, Why}) ->
    logger:warning("[island] raid ~s was refused, party stays home: ~s",
                   [RaidId, terse(Why)]),
    refused.

%% ⚠⚠ NEVER `~p' A RAID FAILURE. THE REASON CONTAINS THE REQUEST, AND THE REQUEST
%% CONTAINS TWELVE PACKED GENOMES.
%%
%% `dronex_mesh:call/3' wraps whatever went wrong, and a lost call carries the
%% arguments back inside the exit reason — so `~p' printed the whole raiding
%% party. Measured on beam03, 2026-08-06: ONE refused raid was about 34,000 lines
%% and 18 MB, and twelve hours of them made a 5.9-million-line log in which the
%% only human-readable lines were 175 warnings that no `grep' could reach in
%% reasonable time. Diagnosing the raid defect meant working around this log
%% first.
%%
%% `~P' with a depth bounds ANY shape, which matters because the interesting
%% failures are the ones whose shape nobody predicted. Depth 4 keeps
%% `{call_failed, exit, {timeout, ...}}' legible and stops at the payload.
terse(Why) -> io_lib:format("~P", [Why, 4]).

new_raid_id() -> string:lowercase(binary:encode_hex(crypto:strong_rand_bytes(16))).

%%==============================================================================
%% Being raided
%%==============================================================================

%% ⚠ THIS RUNS IN MACULA'S PROCESS, NOT THE ISLAND'S. It validates, asks the
%% island for a defending party (fast), then flies the whole engagement HERE and
%% casts the outcome back. The island keeps ticking, publishing and breeding
%% throughout, which is what lets a popular island stay alive while being ground
%% down by attention.
host_a_raid(Request, Island) ->
    answered(dronex_raid:decode_request(Request), Island).

answered({error, Why}, _Island) -> {error, Why};
answered({ok, Req}, Island) -> checked(dronex_raid:validate_request(Req, raid:party() * 2), Req, Island).

checked({error, Why}, _Req, _Island) -> {error, Why};
checked(ok, Req, Island) -> defended(gen_server:call(Island, {defend, Req},
                                     dronex_raid:muster_timeout_ms()), Req, Island).

%% ⚠ THE CALL RETURNS HERE, BEFORE A SINGLE TICK IS SIMULATED. Validation and
%% mustering are the whole of the synchronous part, and both are fast. The fight
%% runs in a process of its own and its outcome travels as a fact, so the caller
%% is never waiting on somebody else's engagement and the defender is never
%% holding a call open while it works.
defended({error, Why}, _Req, _Island) -> {error, Why};
defended({ok, Defenders, Index, Stamp}, Req, Island) ->
    Raiders = [{Id, G} || #{id := Id, genome := P} <- maps:get(sortie, Req),
                          {ok, G} <- [drone_genome:unpack(P)]],
    gen_server:cast(Island, {commit_as, defender, maps:get(raid_id, Req),
                             maps:get(attacker, Req), length(Defenders)}),
    _ = spawn(fun () -> hosted(defence:compose(Defenders, Raiders, Index),
                               Defenders, Raiders, Req#{stamp => Stamp}, Island) end),
    dronex_raid:accepted(maps:get(raid_id, Req)).

%% Published from whichever process is not the island's, so neither side's clock
%% stops to announce that it has paid.
commit(RaidId, Role, Against, Island) ->
    dronex_mesh:publish(dronex_facts:topic(committed),
                        dronex_facts:committed(RaidId, Role, Against, Island)).

%% ⚠ NOBODY IS WAITING ON THIS, so its only job is to be honest afterwards. The
%% settlement goes to the attacker as a small fact between islands; the recording
%% goes to everybody on the public realm. Two audiences, two sizes, two realms.
hosted({error, Why}, _D, _R, Req, Island) ->
    %% The attacker was told yes and its party is committed, so a defender-side
    %% failure still owes it an answer. Total loss is the truth: nothing flew.
    logger:warning("[island] accepted raid ~s then could not host it: ~s",
                   [maps:get(raid_id, Req), terse(Why)]),
    gen_server:cast(Island, {published, settle(Req, draw, [])});
hosted({ok, Arena, Controllers, Pairs}, Defenders, Raiders, Req, Island) ->
    %% The defender fights at home with its network and the attacker flew in
    %% without one. `defence:host/1' owns that, because it is a fact about
    %% defending rather than a fact about this process.
    Result = (defence:host(Controllers))(Arena),
    Fates = defence:fates(maps:get(attackers, Pairs), Result),
    Survivors = defence:survivors(maps:get(defenders, Pairs), Result),
    Meta = maps:merge(
             maps:get(stamp, Req, #{}),
             #{from => maps:get(attacker, Req), raid => maps:get(raid_id, Req),
               tick => maps:get(tick, Req, 0),
               defenders => length(Defenders), defenders_home => length(Survivors)}),
    gen_server:cast(Island, {defended, Survivors, Defenders, Raiders, Meta}),
    %% ⚠ COUNTED, NOT DISCARDED, AND IT WAS DISCARDED FIRST. This runs off the
    %% island's process, so its publish counters cannot see it unless it is sent
    %% back. Thrown away, a raid fact that never leaves looks exactly like a raid
    %% that never happened — and the first thing the raid diagnostic did was
    %% watch the public realm for four minutes while both islands were
    %% demonstrably raiding, and see nothing at all.
    gen_server:cast(Island, {published, settle(Req, defence:outcome(Result), Fates)}),
    gen_server:cast(Island, {published, publish_raid(Result, Fates, Meta)}).

settle(Req, Outcome, Fates) ->
    dronex_mesh:publish_between_islands(
      dronex_facts:topic(settled),
      dronex_facts:settled(maps:get(raid_id, Req), Outcome, Fates)).

publish_raid(Result, Fates, Meta) ->
    dronex_mesh:publish(dronex_facts:topic(raid), dronex_facts:raid(Result, Fates, Meta)).

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
