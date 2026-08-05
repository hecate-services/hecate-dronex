# What crosses the mesh

**This exists so a raid can be requested by a stranger, run by whoever was
attacked, and watched by anybody, with each of the three trusting the others as
little as possible.**

---

## Two directions, two realms, and the asymmetry is the access control

| direction | realm | why |
|---|---|---|
| a raid request, **in** | the **fleet** realm | running a stranger's swarm costs a shared four-core box real CPU, so it is gated |
| every fact, **out** | `net.beamcampus.dronex` | a public web container must never hold the fleet tag |

```
net.beamcampus.dronex
686fbbf84c5c33455764f4c07c642bd1b79ef4efc78455f61ac12936ca3bffe3
```

A realm id is the sha256 of its name, so a public realm is **derived rather than
issued**, needs no provisioning, and its name being public is the entire point.
macula is realm-per-call, so one pool publishes to any realm and this is a second
realm rather than a second connection. It costs nothing to draw the line.

⚠ **Honest limit: stations are realm-agnostic.** A realm is a routing namespace
and not an enforced permission. What this buys is that the public site box never
holds the fleet tag, not that the fleet tag would be refused if it did.

⚠ **A malformed realm tag is an error, never a fallback.** Falling back on a typo
would publish public facts onto the operational realm and report success, which
is the one outcome nobody would notice.

## The topics

Three, deliberately separate, because they have different sizes and different
rates and folding them would make every reader pay for the largest.

| topic | carries | size | kept |
|---|---|---|---|
| `dronex/vitals` | counts, roster depth, benchmark profile, signal volume, ablation delta, tick | small | forever |
| `dronex/raid` | one engagement: entrants, outcome, **and its frames** | ~100 KB | latest only |
| `dronex/roster` | a census: generations, lineage origins, archive size | medium | latest only |

**The island id is in the payload and never in the topic.** A thousand islands
would be a thousand topics, subscription management collapses, and a reader who
wants *all islands* cannot ask for it. One topic, an `island_id` field, and a
subscriber filters. The namespace separates whole **deployments**, a laptop from
the fleet, and is not how islands are told apart.

**Totals rather than rates**, because a rate is recoverable from two totals and a
total is not recoverable from rates. A reader that misses a fact can still work
out what happened across the gap.

**The tick is on every fact.** Publishing runs on wall clock and the island runs
at its own pace, so two consecutive facts may be one tick apart or a million.
Without it a reader cannot tell a stalled island from a slow one.

## The wire rules, each earned by something that broke

- **Atom keys only, no tuples as values.** A tuple does not survive the encoder
  cleanly, and an atom key and a binary key of the same name **collide into one**:
  `#{foo => 1, <<"foo">> => 2}` ships two entries and arrives with one.
- **`fact_version` bumps on every shape change, including an append.** A reader
  has no other way to ask whether the field it wants is in this frame or whether
  it is talking to an island that predates it. A sibling appended a field, the
  site's positional mirror did not follow, the earlier indexes went on decoding
  correctly, and nothing looked wrong.
- **Names travel with vectors.** The benchmark profile ships its rung names beside
  its numbers, so a reader never has to mirror an order in its own source.
- **Integers, and floats only where they are the quantity.** macula 7.0 carries
  IEEE binary64 natively and this was verified byte-exact, so a float is allowed;
  it is still avoided where an integer is the honest representation.

⚠ **Anything read off a wire gets a test that pushes the real message through the
real handler.** Charter rule 6. On the sibling, a reader matched
`{macula_event, Ref, Topic, Payload}` while the SDK sends **five** elements with
a `meta` on the end, so every fact fell through a catch-all and was discarded
silently for an hour, with 226 published and 0 failed at the other end and every
checkable thing checking out.

## Availability, and why it is pub/sub while the challenge is not

⚠ **Added 2026-08-05, replacing "an island picks a target from the islands it
has heard publish".** That worked by subscribing to `dronex/vitals` — thirty
fields including a benchmark ladder and ablation deltas, once a second, from
every island — and reading one thing from it: who exists.

**A protocol is a combination of both mechanisms, and the split is by nature:**

| part | nature | mechanism |
|---|---|---|
| who can be fought | ambient, no answer wanted | **pub/sub** |
| may I attack you | addressed, needs an immediate definite yes/no | **RPC** |
| the fight | slow work with one owner | neither, it is work |
| what happened | a fact about two islands | **pub/sub** |

⚠⚠ **The challenge stays RPC because admission control needs a serialisation
point.** Two attackers both see an island open, both muster, both send. Only a
synchronous accept can turn one of them away *before* it has committed a party;
with pub/sub alone both would learn afterwards, and the roster's finiteness is
the whole price of a raid.

### `dronex/island_opened_for_battle` is a LEASE

Re-announced while open, expired by the listener if it stops arriving. A bare
`opened` would be edge-triggered distributed state: one lost message and a
neighbour believes you are open for ever, spending two minutes per raid on a
corpse.

⚠ **The lease is long on purpose, and that is a design decision rather than a
tuning one.** Announced every 30s, believed for five minutes.

| lease | resting state | consequence |
|---|---|---|
| short | **closed** | neglect keeps you safe. Islands drift into turtling, no genomes cross, and the one idea dies while the exhibit still looks busy |
| long | **open** | staying open is what happens if you do nothing. Closing is an act, and being popular costs airframes |

The second is what this design wants, because the turtling failure is the one it
is most at risk of. Death still clears the entry, which is what a lease is for.

**An island announces open only when it actually is.** The published state is
derived from whether the raid procedure is really registered and whether a
defence can be mustered above the floor — never asserted beside them. Without
that an island can announce itself open, be believed, and answer nothing, which
is REGISTER I.11 exactly.

Two fields ride along, and each turns a wasted raid into a filter: the **engine
fingerprint**, because a mismatch would refuse on arrival, and the **roster
depth**, because an island at its floor has nobody to field.

**Presence stays on `dronex/vitals`.** The site needs the islands that are
CLOSED — a turtling island is still land on the map, arguably the most
interesting thing on it — so deriving presence from the opening topic would draw
the combatants and quietly omit everyone who chose not to fight. `open` also
rides on `vitals`, so the map can tell the two apart without subscribing to the
availability topics at all.

## The raid protocol

```
attacker                                            defender
--------                                            --------
pick N from roster, remove them
  |
  |  raid_requested   (fleet realm)
  |    attacker island_id, raid_id,
  |    N packed genomes, engine fingerprint
  '------------------------------------------------->
                                          validate every genome
                                          refuse the WHOLE raid on any failure
                                          pick M from own roster, remove them
                                          run the engagement
                                          keep the attacker's genomes
                                                     |
  <--------------------------------------------------'
  |  raid_settled    (reply)
  |    outcome, per-genome fate, survivor weights
  |
  survivors return to the roster
  the dead do not
                                                     |
                                     dronex/raid  (public realm)
                                       the whole engagement, with frames
                                                     '--------> everybody
```

**Every foreign genome is validated before the engagement starts, never during.**
A genome that fails validation makes the **whole raid refuse** rather than one
entrant silently misbehaving, because a wrong-width input layer is padded in
silence and a short output vector falls back to a null command. A mismatched
genome therefore does not crash: it fights badly and produces a result that
looks real.

**The engine fingerprint travels with the request**, and a mismatch refuses.
Two islands on different builds produce results that are comparable to nothing,
and the sibling shipped exactly that: the site pinned one engine commit and the
service pinned another, and the only thing between that and drawing a fight
nobody fought was a turn-count self-check.

⚠ **The reply carries survivor weights, not just fates**, because under arm L the
weights that come home differ from the ones that left. Under arm W the attacker
already has them and the field is redundant; it is sent either way so the wire
shape does not depend on a runtime dial.

## The frame budget

A raid publishes its frames. The numbers, so the decision is checkable rather
than asserted:

```
16 drones x 8 integers per drone per frame       = 128 integers
60 second cap at 20 Hz, one frame every 2nd tick =  600 frames
                                                 -------------
                                                   76,800 integers
                                       CBOR small ints, ~2 bytes -> ~150 KB
```

The transport cap is **1 MiB** per frame on macula's QUIC path
(`macula_net_transport_quic`, `?MAX_FRAME_BYTES` = `16#100000`); the protocol
frame cap above it is 16 MiB. So a raid fits with roughly an order of magnitude
to spare, and 1 MiB is the number to watch if the swarm size or the cap ever
grows.

Positions are quantized to the nearest metre **for the frames only**. The
simulation runs at millimetre resolution; nothing is drawn at millimetre
resolution.

⚠ **A raid is a recording, published once when it is over, not a stream.** The
site stores it and animates locally with no server round trip. That is what makes
scrub, pause and slow motion possible, it is cheaper than a live feed, and it
satisfies the site's standing rule that it aggregates and visualizes rather than
regenerating.

## Facts an island publishes about itself

`dronex/vitals`, once a second, small enough to keep forever:

```erlang
#{fact_version    => N,
  island          => <<"beam02">>,      %% a nickname, may be shared
  island_id       => <<"...">>,         %% 128 bits, nobody types it
  tick            => T,
  roster          => Depth,
  capacity        => Cap,
  generation      => G,
  benchmark_rungs => [hoverer, climber, orbiter, chaser, evader, screener],
  benchmark       => [S1, S2, S3, S4, S5, S6],
  archive         => DistinctBehavioursEverSeen,
  opponents       => #{drills => D, champions => C, captured => F},
  foreign_share   => Percent,
  signal_volume   => V,
  ablation_delta  => Delta,
  sorties_sent    => S, sorties_returned => R,
  raids_defended  => Dfd, raids_repelled => Rep,
  refused_genomes => Ref,
  station_host    => Host, station_id => Key, station_connected => Bool}
```

**`station_host` is configuration echoed back; `station_id` is the station's
Ed25519 key from the signed HELLO.** Both go out, because they are different
claims and a reader is entitled to see them disagree.

⚠ **A name is not a place.** `station-de-frankfurt` was for a long time
physically the Nuremberg box and has since moved again. Stations are virtual and
there are hundreds of names over a handful of machines, so **nothing downstream
may render a city from this**.

## Identity, and the four things that break without it

`island` is a **label**: an environment variable falling back to the hostname,
changeable at runtime. Two islands can carry the same one, and in an
archipelago of machines run by strangers they eventually will. Filed under the
name, four things break:

- a spectator **merges** them, and the map shows one island flickering between
  two rosters
- they land on **one square**, because a derived layout hashes what it is given
- a raid becomes **ambiguous**, delivered to the wrong island or twice
- and anyone may type your island's name into their own config and begin
  collecting your sorties

So identity is 128 bits minted once into the data directory, which nobody types,
and the name is a nickname. Two islands may both be called `beam01` exactly as
two people may both be called Raf.

⚠ **This defeats accident and not impersonation.** Nothing signs it. Doing better
needs a persisted mesh keypair, which `hecate_om` loads only when
`identity_key_path` is configured; the pool's key is ephemeral, so an island keyed
on it would be a new island at every restart. Named in the charter as owed.

## A dark mesh is not a failure

An island whose neighbours are unreachable is still an island. Its trainer runs,
its roster grows, its benchmark is measured, and the only thing lost is that
nobody else hears about it and nobody attacks it.

So a publish that cannot happen **returns an error to a caller that shrugs**,
counted rather than logged, rather than taking the island down. What must never
happen is silence that looks like success, which is why the failure is a return
value and not a swallowed exception.

`hecate_om_identity:macula_client/0` is a `gen_server` call, so before
`hecate_om` is up it does not return an error, it **exits with `noproc`**.
Unwrapped, that exit travels up through the publish timer and kills the island,
losing the roster in memory. It is wrapped for exactly that reason.
