%% @doc WHAT AN ISLAND SAYS ABOUT ITSELF, AND WHERE IT SAYS IT. PURE.
%%
%% ONE FACT SO FAR, `dronex/vitals': what exists at this commit and not a field
%% more. Small enough to keep for ever, which is what a statistics reader wants.
%%
%% ⚠ THE DESIGN NAMES A DOZEN MORE FIELDS AND NONE OF THEM IS HERE YET. The
%% benchmark profile, the ablation delta, the sortie counts, the opponent-set
%% composition and the coverage summary all arrive in the same commit as the
%% thing that computes them. A field published before it means anything is a
%% number a reader will chart, and a chart of a constant zero is indistinguishable
%% from a chart of a mechanism that does not work.
%%
%% THE ISLAND ID IS IN THE PAYLOAD AND NEVER IN THE TOPIC. Putting it in the
%% topic is the mistake that scales worst: a thousand islands become a thousand
%% topics, subscription management collapses, and a reader who wants "all
%% islands" cannot ask for it. One topic, an `island_id' field, and a subscriber
%% filters. The namespace separates whole DEPLOYMENTS, not islands.
%%
%% TOTALS RATHER THAN RATES, because a rate is recoverable from two totals and a
%% total is not recoverable from rates. A reader that misses a fact can still work
%% out what happened across the gap.
%%
%% THE TICK IS ON EVERY FACT, and it is not decoration. Publishing runs on wall
%% clock and the island runs on its own pace, so two consecutive facts may be one
%% tick apart or a million. Without the tick a reader cannot tell a stalled island
%% from a slow one.
%%
%% ==========================================================================
%% WIRE RULES, EACH EARNED BY SOMETHING THAT BROKE
%% ==========================================================================
%%
%% Atom keys only, no tuples as values, integers rather than floats. A tuple does
%% not survive the encoder cleanly, and an atom key and a binary key of the same
%% name collide into one: `#{foo => 1, <<"foo">> => 2}' ships two entries and
%% arrives with one.
%%
%% NAMES TRAVEL WITH VECTORS. Nothing here is a vector yet. When the benchmark
%% profile arrives it carries its rung names beside its numbers, because a
%% sibling shipped positional lists, appended a field, and the reader's mirror
%% did not follow: the earlier indexes went on decoding correctly, so nothing
%% looked wrong.
-module(dronex_facts).

-export([topic/1, topics/0, namespace/0, fact_version/0]).
-export([vitals/2, bout/4, raid/3, opened/1, closed/0, settled/3, committed/4]).

-define(DEFAULT_NS, <<"dronex">>).

%% ⚠ BUMPED WHENEVER THE SHAPE CHANGES, INCLUDING AN APPEND. A reader has no
%% other way to ask "is the field I want in this frame, or am I talking to an
%% island that predates it".
%%
%% 3 adds `dronex/bout', a whole engagement published as a recording. The vitals
%% shape is unchanged; the version moves because a reader that wants to know
%% whether an island publishes bouts at all has no other way to ask.
%% 2 adds the trainer and the frozen exam: `generation', `rounds', `admissions',
%% and the benchmark profile with its rung names beside it. They arrive together
%% because they arrived together in the code: an island that breeds without
%% publishing what it sat is an island whose numbers cannot be read.
%% 1 was the first fact this track ever published.
-define(FACT_VERSION, 3).

-spec fact_version() -> pos_integer().
fact_version() -> ?FACT_VERSION.

%% Topics are `<namespace>/<leaf>'. The namespace tells one deployment from
%% another, for instance a laptop from the fleet, and is NOT how islands are
%% distinguished.
-spec topic(atom()) -> binary().
topic(vitals) -> leaf(<<"vitals">>);
%% ITS OWN TOPIC, so a reader chooses whether to hear it. Vitals are counts and
%% are small enough to keep forever; a bout is a recording of tens of kilobytes
%% and a statistics reader must not have to take one to get the other.
topic(bout) -> leaf(<<"bout">>);
%% ⚠ A RAID IS ABOUT TWO ISLANDS AND EVERY OTHER FACT IS ABOUT ONE, which is why
%% it is worth its own topic rather than riding `bout'. A reader collecting the
%% archipelago's history wants these and may not want a training bout every
%% twenty seconds from every island.
topic(raid) -> leaf(<<"raid">>);
%% ==========================================================================
%% ⚠ AVAILABILITY IS A DECISION, AND IT IS THE ONLY THING ISLANDS TELL EACH OTHER
%% ==========================================================================
%%
%% Islands subscribe to these two and to nothing else. They used to subscribe to
%% `vitals' — thirty fields including a benchmark ladder and ablation deltas,
%% once a second, from every island — purely to learn who existed. That is a
%% spectator's fact and islands were reading it for one field.
%%
%% PRESENCE STAYS ON `vitals', where the site reads it, because the site needs
%% islands that are CLOSED. A turtling island is still land on the map, and
%% deriving presence from these topics would draw the combatants and quietly omit
%% everyone who chose not to fight.
topic(opened) -> leaf(<<"island_opened_for_battle">>);
topic(closed) -> leaf(<<"island_closed_for_battle">>);
%% ⚠ SMALL, AND SEPARATE FROM THE RECORDING BECAUSE OF WHAT THE RECORDING
%% WEIGHS. `raid' carries frames, of the order of 150 KB. An attacker needs six
%% genome fates to put its survivors back, which is a few hundred bytes. Settling
%% off the public recording would make every island download every fight in the
%% archipelago to learn the outcome of its own.
topic(settled) -> leaf(<<"raid_settled">>);
%% ⚠ PUBLIC, UNLIKE THE SETTLEMENT, AND BOTH SIDES EMIT IT. The settlement is
%% addressed and must stay small; a commitment's whole value is the record and
%% the map. There is nothing to hide once the recording will be public anyway.
topic(committed) -> leaf(<<"island_committed_to_battle">>).

%% @doc Every topic this island publishes on.
%%
%% ⚠ EXPORTED SO THE SERVICE'S `identity_spec/0' CAN ASK FOR EXACTLY THESE AND NO
%% MORE, and so a test can compare the two. Authority that names a topic nothing
%% publishes to is a credential lying around; publishing to a topic the spec does
%% not name is a call the realm would refuse once delegation lands. A sibling
%% drifted exactly that way.
%%
%% `dronex/roster' is designed and is deliberately absent until something
%% publishes it. `dronex/raid' joined the list at item 7, when a defender started
%% publishing the fights it hosts. `dronex/bout' is here because something does:
%% an island's own best controller against one of its drills, which is what an
%% island actually spends its time doing.
-spec topics() -> [binary()].
topics() ->
    [topic(vitals), topic(bout), topic(raid),
     topic(opened), topic(closed), topic(settled), topic(committed)].

leaf(Leaf) -> <<(namespace())/binary, "/", Leaf/binary>>.

-spec namespace() -> binary().
namespace() -> ns(os:getenv("HECATE_DRONEX_NS")).

ns(false) -> ?DEFAULT_NS;
ns("") -> ?DEFAULT_NS;
ns(Str) -> list_to_binary(string:trim(Str)).

%% @doc What this island is, right now.
%%
%% Takes the island rather than reading anything about it, so it stays pure and a
%% test can build one without a running node.
%%
%% `station_*' is the exception and it is read, because the door this island is
%% actually speaking through is a property of the live connection and not of the
%% island. It is merged in rather than passed, so a caller cannot forget it.
-spec vitals(island:island(), map()) -> map().
%% ⚠ `Runtime' IS THE SERVER'S VIEW OF ITSELF, and it is a map rather than a
%% growing argument list because it has grown twice already: the roster writer's
%% counts at item 5, and whether this island is reachable at item 7.
vitals(Island, Runtime) ->
    Writer = maps:get(writer, Runtime),
    maps:merge(
      #{fact_version => ?FACT_VERSION,
        island => dronex_identity:island(),
        island_id => dronex_identity:island_id(),
        tick => island:tick_of(Island),
        %% Zero at this commit, and published anyway. CHARTER.md rule 4: a
        %% capacity that was never exercised is not evidence of anything, so the
        %% count goes out beside the null from the first fact. An island with an
        %% empty roster and an island that does not report a roster look
        %% identical otherwise.
        roster => island:roster_depth(Island),
        capacity => island:capacity(Island),
        generation => island:generation_of(Island),
        %% ⚠ EXERCISE COUNTS BESIDE EVERY NULL. CHARTER.md rule 4. A trainer that
        %% has proposed nothing and a trainer whose every proposal was rejected
        %% look identical without these, and they are different situations.
        %% ⚠ WHO SAT THE EXAM, because `roster:best/1' can be a CAPTURED genome.
        %% A raid admits foreign controllers into the same roster the champion is
        %% chosen from, so an island's headline score can belong to a controller
        %% bred on another machine — and without this field a reader cannot tell
        %% an evolutionary collapse from a change of champion. Two words on the
        %% wire against a number nobody could interpret.
        benchmark_sitter => sitter(island:sitter_of(Island)),
        rounds => island:rounds_of(Island),
        admissions => island:admissions_of(Island),
        %% CHARTER.md rule 4 again, for the mechanism the whole repository is
        %% named after. Zero raids and zero defences is a fact; so is many raids
        %% and zero captures, and they mean opposite things.
        raids => island:raids_of(Island),
        raids_home => island:raids_home_of(Island),
        raids_lost => island:raids_lost_of(Island),
        defences => island:defences_of(Island),
        captures => island:captures_of(Island)},
      maps:merge(maps:merge(station(), reachability(Runtime)),
                 maps:merge(persistence(Writer),
                            maps:merge(frozen(island:benchmark_of(Island)),
                                       ablation(island:ablation_of(Island),
                                                island:ablations_of(Island)))))).

%% ⚠ WHETHER THE LINEAGE IS ACTUALLY BEING SAVED, AND IT GOES OUT BECAUSE IT
%% ONCE WAS NOT. The first deployed island wrote nothing for four minutes and
%% looked perfectly healthy doing it: `/health' answered `ok', the container
%% reported `healthy', and the only visible symptom was a tick that had stopped
%% moving, which a reader would have had to be watching for.
%%
%% `roster_writes' rising is the island saving what it has bred.
%% `roster_write_failures' rising is a store refusing it.
%% `roster_writes_dropped' rising is normal: a snapshot is full state, so one
%% superseded before it was written cost nothing but is counted anyway, because a
%% writer that drops everything and one that drops nothing must look different.
persistence(#{written := W, failed := F, dropped := D}) ->
    #{roster_writes => W, roster_write_failures => F, roster_writes_dropped => D}.

%% ⚠ WHETHER THIS ISLAND CAN BE RAIDED AT ALL, AND IT TOOK A SIX-STEP DIVE TO
%% FIND OUT ONCE. An island that failed to advertise still breeds, still
%% publishes, still answers `/health', still hears its neighbours and still
%% raids them. From every outside angle it is a healthy, busy island. It simply
%% cannot be attacked back, and the only symptom is that somebody else's
%% `defences' counter never moves — a number on a different machine.
%%
%% `advertising' false with `listening' true is exactly that state, and it is
%% worth its own field because the two failed independently: subscribing reads
%% the public realm out of an environment variable, while advertising has to ask
%% `hecate_om' for the fleet realm and could not at boot.
reachability(Runtime) ->
    #{advertising => maps:get(advertising, Runtime, false),
      listening => maps:get(listening, Runtime, false),
      %% ⚠ ON VITALS AS WELL AS ON ITS OWN TOPIC, and the duplication is for two
      %% audiences with different needs. Islands want it pushed, small and on
      %% change; the site wants it beside everything else it already draws, so
      %% that a turtling island can be drawn differently from a fighting one
      %% without subscribing to the availability topics at all.
      open => maps:get(open, Runtime, false)}.

%% ⚠ THE THREE NUMBERS FROM `DESIGN_DRONES_THAT_TALK.md', AND THE FOURTH THAT
%% MAKES THEM READABLE. Volume, delta and entropy each mean something specific
%% when they are zero, and none of those meanings is available unless the reader
%% can also tell whether the measurement was ever taken. `ablations' is that, and
%% it is why an island that has not ablated publishes zeros with a zero count
%% rather than publishing nothing.
ablation(undefined, Count) ->
    #{signal_volume => 0, signal_entropy => 0, ablation_void => true,
      ablation_delta_air => 0, ablation_delta_ground => 0, ablation_delta_all => 0,
      ablations => Count};
ablation(Report, Count) ->
    #{air := Air, ground := Ground, all := All} = maps:get(delta, Report),
    #{mean := Entropy} = maps:get(entropy, Report),
    %% ⚠ FLAT KEYS RATHER THAN A NESTED MAP. A spectator reads these beside the
    %% benchmark rungs, which are already flat, and a nested map would make the
    %% page's decoder branch on shape for no gain on the wire.
    #{signal_volume => maps:get(volume, Report),
      signal_entropy => Entropy,
      ablation_void => maps:get(void, Report),
      ablation_delta_air => Air,
      ablation_delta_ground => Ground,
      ablation_delta_all => All,
      ablations => Count}.

%% ⚠ THE RUNG NAMES TRAVEL WITH THE NUMBERS. A sibling shipped positional lists,
%% appended a field, and the reader's mirror did not follow: the earlier indexes
%% went on decoding correctly, so nothing looked wrong.
%%
%% ⚠⚠ AND THE PROFILE IS NEVER SUMMED ON THE WIRE ANY MORE THAN IT IS IN MEMORY.
%% There is no `benchmark_score' field and there will not be one: a single number
%% needs weights, and weights are a judgement about which rung matters smuggled
%% into a measurement.
frozen(Profile) ->
    #{benchmark_rungs => maps:get(rungs, Profile, []),
      benchmark_wins => maps:get(wins, Profile, []),
      benchmark_draws => maps:get(draws, Profile, []),
      benchmark_losses => maps:get(losses, Profile, []),
      %% Zero means the exam has not been sat, which a reader must be able to
      %% tell from having sat it and lost everything.
      benchmark_starts => maps:get(starts, Profile, 0)}.

%% A door that cannot be read is reported as unknown rather than omitted. A key
%% that appears only sometimes is a field a chart silently drops.
station() -> described(dronex_mesh:station()).

described({ok, Door}) -> Door;
described({error, _Why}) ->
    #{station_host => <<"unknown">>,
      station_connected => false,
      station_id => <<>>}.

%% @doc I can be fought, and here is what you need to know before trying.
%%
%% ⚠ A LEASE, NOT AN EVENT. Re-announced while open and expired by the listener
%% if it stops arriving, because a bare `opened' is edge-triggered distributed
%% state: one lost message and a neighbour believes you are open for ever, and
%% raids against a corpse cost two minutes each.
%%
%% ⚠⚠ AND THE TTL IS LONG ON PURPOSE, WHICH IS A DESIGN DECISION AND NOT A
%% TUNING ONE. A short lease makes CLOSED the resting state: neglect keeps you
%% safe, islands drift into turtling, no genomes cross the mesh, and the
%% charter's one idea dies while the exhibit still looks busy — which
%% `DESIGN_THE_ROSTER_AND_THE_RAID.md' names as the failure it is most at risk
%% of. A lease renewed easily while alive makes OPEN the resting state: staying
%% open is what happens if you do nothing, closing is an act, and being popular
%% costs airframes. Death still clears the entry, which is what a lease is for.
%%
%% The two extra fields each turn a wasted raid into a filter: an incompatible
%% ENGINE would refuse on arrival, and an island near its ROSTER floor would
%% refuse for want of anybody to field.
%% Bred here, captured from a neighbour, or an island that has not sat one yet.
%% Deliberately NOT the raid id or the opponent: this is a provenance flag for a
%% public page, and the fleet's raid ids are not its business.
sitter({bred, _Whose}) -> <<"bred">>;
sitter({captured, _From, _Raid}) -> <<"captured">>;
sitter(_unknown) -> <<"unknown">>.

-spec opened(island:island()) -> map().
opened(Island) ->
    #{fact_version => ?FACT_VERSION,
      island => dronex_identity:island(),
      island_id => dronex_identity:island_id(),
      fingerprint => dronex_raid:fingerprint(),
      roster => island:roster_depth(Island)}.

%% @doc I am no longer a target. Immediate, so choosing to turtle costs seconds
%% rather than the lease.
-spec closed() -> map().
closed() ->
    #{fact_version => ?FACT_VERSION,
      island => dronex_identity:island(),
      island_id => dronex_identity:island_id()}.

%% @doc Airframes are spent, and this is who spent them on what.
%%
%% ⚠ THE RECORD OF A RAID WAS ONE-SIDED UNTIL THIS EXISTED. Only the defender
%% published anything — the settlement and the recording — so a defender that
%% went dark after accepting left the attacker six airframes poorer with NOTHING
%% anywhere recording that the raid had happened. The sweep wrote the party off
%% in silence. Two witnesses is not redundancy: `I committed six against D' and
%% `I committed six against A' are different claims and neither is authoritative
%% over the other.
%%
%% ⚠⚠ EMITTED ON ACCEPTANCE, NOT ON MUSTER. A party that is refused comes home,
%% so a commitment published when the genomes left the roster would name raids
%% that never happened. Committed means accepted and the price is paid, which is
%% the same instant on both sides.
%%
%% What it buys beyond the record: commitments without settlements becomes a
%% measurable rate rather than an invisible one, a raid in flight becomes
%% drawable before it is over, and an island being attacked by several at once
%% becomes visible instead of merely inferable from a roster shrinking.
-spec committed(binary(), attacker | defender, {binary(), pos_integer()},
                island:island()) -> map().
committed(RaidId, Role, {Opponent, Airframes}, Island) ->
    #{fact_version => ?FACT_VERSION,
      island => dronex_identity:island(),
      island_id => dronex_identity:island_id(),
      raid_id => RaidId,
      role => Role,
      opponent_id => Opponent,
      airframes => Airframes,
      %% ⚠ THE ATTACKER'S SIDE OF THE STAMP, AND THE ONLY PLACE IT CAN COME FROM.
      %% A raid recording is published by the DEFENDER, which knows its own
      %% roster and nothing about its opponent's. Both sides emit a commitment,
      %% so stamping it here is what lets a reader order a raid by where the
      %% RAIDER was in its evolution rather than only the host.
      generation => island:generation_of(Island),
      rounds => island:rounds_of(Island)}.

%% @doc What happened to the attacker's genomes, addressed by raid.
%%
%% ⚠ THE ATTACKER'S SETTLEMENT ARRIVES AS A FACT RATHER THAN AS A RETURN VALUE,
%% so the defender is never holding somebody else's call open while it fights,
%% and a settlement that is missed can be waited for rather than lost. The
%% attacker matches `raid_id' against the parties it has out.
-spec settled(binary(), attacker | defender | draw,
              [{binary(), dronex_raid:fate()}]) -> map().
settled(RaidId, Outcome, Fates) ->
    #{fact_version => ?FACT_VERSION,
      island => dronex_identity:island(),
      island_id => dronex_identity:island_id(),
      raid_id => RaidId,
      outcome => Outcome,
      fate => [#{id => Id, fate => F} || {Id, F} <- Fates]}.

%% @doc A raid, as a recording plus who lost what.
%%
%% ⚠ PUBLISHED BY THE DEFENDER, BECAUSE THE DEFENDER RAN IT. One engine produced
%% these frames and it is the one being attacked; an attacker publishing its own
%% raid would be publishing a fight it simulated itself, and nothing on the wire
%% could contradict it.
%%
%% ⚠⚠ AND IT NAMES BOTH ISLANDS. A raid is the only fact in this deployment that
%% is ABOUT two islands rather than about one, so a reader that files facts under
%% the publisher would file it under the defender alone and the attacker's half
%% of the story would have no home. Both identities travel.
%% ⚠ NO REQUEST ARGUMENT. The first version took one and read nothing from it,
%% because `Meta' already carries the attacker, the raid id and the tick. A
%% parameter that is threaded through and never read is REGISTER I.7, and this is
%% the second time in one sitting, so it is worth saying plainly: if the caller
%% has to hand this function a thing to be polite, the thing does not belong.
-spec raid(map(), [{binary(), dronex_raid:fate()}], map()) -> map().
raid(Result, Fates, Meta) ->
    maps:merge(
      #{fact_version => ?FACT_VERSION,
        island => dronex_identity:island(),
        island_id => dronex_identity:island_id(),
        attacker_id => maps:get(from, Meta),
        raid_id => maps:get(raid, Meta),
        %% ⚠ WHERE THIS ISLAND WAS IN ITS OWN EVOLUTION WHEN THIS HAPPENED.
        %% Recordings carried a TICK and nothing about the roster that produced
        %% them, so nothing longitudinal could ever be asked of them — "did
        %% spacing improve", "did specialisation emerge" — because there was no
        %% way to order two recordings by anything but wall clock, and wall clock
        %% is not what evolves.
        %%
        %% ⚠⚠ BOTH NUMBERS, BECAUSE THEY MEASURE DIFFERENT THINGS AND ONE OF THEM
        %% LIES ABOUT THE OTHER. `generation' is `lists:max' over the roster's
        %% entries and a raid admits CAPTURED genomes at generation 0, so an
        %% island that absorbs a swarm has its generation cut without breeding
        %% less. `rounds' is the breeding clock and only ever climbs. A reader
        %% given one of them will use it as though it were the other.
        generation => maps:get(generation, Meta, 0),
        rounds => maps:get(rounds, Meta, 0),
        %% How many of the attacker's genomes came home. The defender's own
        %% losses are its business and are visible in its roster depth; what a
        %% spectator needs is the price the RAID paid, which is what makes an
        %% archipelago of raids readable as something other than a light show.
        raiders => length(Fates),
        raiders_home => length([F || {_Id, F} <- Fates, F =:= survived]),
        %% ⚠ THE DEFENDER'S HALF OF THE LEDGER, WHICH WAS MISSING. Only the
        %% attacker's losses were published, so a reader could see what a raid
        %% cost the raider and not what it cost the island that beat it. Both
        %% sides pay on the same terms and a score that shows one of them is not
        %% a score.
        defenders => maps:get(defenders, Meta, 0),
        defenders_home => maps:get(defenders_home, Meta, 0)},
      dronex_bout:encode(#{kind => raid,
                           bout => maps:get(tick, Meta, 0),
                           start_index => 0,
                           entrants => [maps:get(from, Meta), dronex_identity:island_id()]},
                         Result, maps:get(frames, Result, []), airspace:limits())).

%% @doc A whole engagement, as a recording.
%%
%% ⚠ SEPARATE FROM `vitals/1' BECAUSE THEY ARE DIFFERENT SIZES AND DIFFERENT
%% RATES. Counts are small enough to keep forever and go out every second; a bout
%% is tens of kilobytes and goes out when one happens. Folding them together
%% would make a statistics reader pay for frames it will never draw, and would
%% force both onto one clock.
-spec bout(island:island(), map(), map(), list()) -> map().
bout(Island, Meta, Result, Frames) ->
    maps:merge(
      #{fact_version => ?FACT_VERSION,
        island => dronex_identity:island(),
        island_id => dronex_identity:island_id(),
        tick => island:tick_of(Island)},
      dronex_bout:encode(Meta, Result, Frames, airspace:limits())).
