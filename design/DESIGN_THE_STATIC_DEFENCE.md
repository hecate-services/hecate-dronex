# The static defence

**This exists so an island is a place with geography rather than a bag of
genomes, and so that attacking is harder than defending for a reason you can
draw.**

---

## Why this is act one and not a deferred division

The counter-UAS line was going to be kept as a contract nothing exercised. That
was the wrong disposition and the reason is the repository's own charter rule 4:
**a capacity that was never exercised is not evidence of anything.** Kept code
that nothing runs rots, and a contract nobody publishes on is a guess about a
future negotiation.

Folding detection into the island now buys four things, and each of them is
worth more than the deferral.

**It makes attack and defence structurally different.** Until now a raid was
symmetric: two swarms drawn from rosters of the same genome shape, flying the
same airframe with the same sensors, in an empty box. Symmetry is the shape P7
found sterile, and 057's whole finding was that a co-adapting symmetric opponent
buys nothing. A static sensor network gives the defender **persistent sensing and
prior knowledge of the ground**, and gives the attacker **initiative and
surprise**. Those are different problems, so the two sides can be good at
different things.

**It gives the attacker something to solve that is not another drone.** Coverage
has holes. Finding an approach path through them is a real evolutionary problem
with an interpretable, drawable answer, and it is a far better first tactical
problem than "converge on the enemy".

**It makes islands look different from each other.** Two islands are currently
two identical boxes with different genomes in them. With a defence network they
have geography: sensor positions, coverage, blind corridors. That is persistent
state, it differs per island, it is publishable, and it is drawable.

**It matches what a counter-drone situation actually is.** Real systems are a
static detection layer cueing an effector. The design so far had the effector and
not the detection, which under the charter's framing is the wrong half to have.

## The rule that makes it an asymmetry rather than an advantage

> **You fight at home with your network, and away without it.**

An island's sensors defend its own airspace. When it raids, its drones fly into
someone else's volume with no ground support at all.

That prices a raid a second time, on top of spending airframes: attacking is
genuinely harder than defending, and choosing to attack means giving up the
thing that makes you strong.

⚠ **And it is the design's most likely failure mode, so the viability criterion
is written down before the dial is set.** If home advantage is overwhelming,
every island turtles, nothing ever raids, no genomes cross, and the charter's one
idea dies quietly while the exhibit still looks busy.

**Criterion, fixed in advance: a competent attacking swarm must win a
non-trivial fraction of raids against a competent defence.** Network strength,
sensor count and detection range are chosen on that, and the whole sweep is
published including the settings that made attacking hopeless. Charter rule 3.

## Cueing goes over the comms channel, and that is the best part

A ground track has to reach a defending drone somehow. The obvious way is new
sensor channels, a `cued_contact_bearing` and so on.

**That would be wrong, for a reason that is structural rather than aesthetic.**
Extra channels for defenders means attackers and defenders have different input
widths, which means two genome shapes, two rosters, and two populations that
cannot be drawn from one pool. The single-population property is what makes a
sortie a draw from the roster rather than an assembly of declared roles, and it
is what makes a captured genome usable by its captor. It is not negotiable for a
convenience.

**So the ground network transmits.** It has a voice on the same uninterpreted
comms channel the drones have, and four consequences fall out for free:

- **a defending drone must learn to use the cue**, because it arrives as four
  integers whose meaning nothing declares, exactly like every other transmission
- **the attacker hears it**, so a network that talks reveals that it has detected
  you, and going loud is a decision rather than a default
- **an attacker can learn to listen**, which is to say learn when it has been
  seen, which is a real capability nobody had to design
- **one genome shape survives**, so an attacker genome and a defender genome are
  the same kind of thing and the roster stays one pool

## But the ground gets its own bank, for instrument reasons

The tempting version is for the ground station to transmit into the friendly-air
bank, costing nothing. That is rejected, and the argument is an instrument
argument, which has been the load-bearing kind throughout this design.

If ground and air share a bank, then muting comms mutes both, and the ablation
can no longer separate **drones coordinating with each other** from **drones
being cued by the ground**. Those are different findings and conflating them
would waste the only instrument that makes either measurable.

So three incoming banks of four:

| bank | carries |
|---|---|
| friendly air | the sum of friendly drone transmissions in range |
| hostile air | the sum of hostile drone transmissions in range |
| **ground** | the sum of ground-station transmissions in range, **whoever owns them** |

Affiliation on the ground bank is implicit rather than labelled. A defender's
ground bank carries its own network; an attacker flying over enemy territory
hears the defender's network on the same bank, and has no ground stations of its
own in that engagement. You hear a radio, and where you are tells you whose it
is.

**Input width goes from 37 to 41.** Four channels for a three-way ablation:

```
mute the air banks    -> did drone-to-drone coordination matter
mute the ground bank  -> did cueing matter
mute both             -> the joint effect, and the interaction
```

## The frozen benchmark runs with no ground network

⚠ **This is not optional and it would have been easy to miss.**

If the benchmark ran at home, an island that improved its fortifications would
show a rising benchmark score, and that score would not be about its drones at
all. That is insight 054's failure mode a second time: a number that reports
progress while measuring something other than the thing it names.

**The benchmark is an away game, always.** Drills, fixed geometries, no sensors,
no cueing, ground bank forced to zero. It measures the controller.

The network gets its own separate published number, and the two are never added
together.

## What a sensor is

The behaviour comes across whole from the counter-UAS line, and it is the best
thing that line produced:

```erlang
-callback observe(Truth :: term(), Sensor :: term(), Env :: term()) ->
    {ok, Contact} | miss.
```

Ground truth in, this sensor's placement and knobs in, the environment in, and
out comes either what this sensor would actually report or nothing at all. **The
consumer cannot tell a simulated sensor from a real one**, which is the swap
point, and it is how a characterised real sensor is ever dropped in.

A sensor has a position, a height, an orientation, a range, a detection
probability that falls with range, and a noise model. It is **terrain, not a
target**: it cannot be destroyed.

⚠ Destructible sensors would give the attacker a second objective, and multiple
objectives is a balance problem this repository has no means to settle. It is the
same reasoning that gives a drone exactly one weapon. Named as the obvious
extension, deliberately not built.

The counterplay to a sensor network is therefore **the approach path**: fly low,
fly around, fly through the gap. That is a better first problem than suppression
and it is the one that draws beautifully.

## The first modality is not Remote-ID, and the second one is

The retained `remote_id_sensor_model` is a working L1 implementation of the
behaviour: presence check, range check, probabilistic detection, position noise,
confidence. Its structure is exactly right.

⚠ **But Remote-ID is the wrong first modality here, and the reason is the whole
point of it.** Remote-ID is a legally mandated broadcast: near-perfect when the
drone announces itself, blind otherwise. An attacking drone does not announce
itself. A defence network built on Remote-ID would see nothing.

So the first modality is **non-cooperative**: range-limited, bearing-heavy,
probabilistic, with detection falling off with range and a false-alarm rate. That
is the sensor that has holes, and holes are what makes an approach path a
problem.

**Remote-ID then becomes the right second modality, for the other side of the
picture.** Friendly drones broadcast, so a defender knows exactly where its own
are and only roughly where the enemy's are. That asymmetry inside the defending
picture is real, it is free, and it is what a defending controller has to reason
over.

## What actually ports, corrected

⚠ **I asserted before reading that the fusion logic was worth porting. It is
not, and the correction matters because it changes what has to be written.**

| piece | verdict |
|---|---|
| `dronex_sensor_model` behaviour | **ports whole.** Three arguments, a contact or a miss. Nothing about it is counter-UAS specific |
| `airspace_contact_observed` field set | **ports as a shape.** Sensor id, modality, observed-at, position, bearing, range, confidence is the right field set |
| ... its map and its wall clock | **does not port.** `observed_at` defaults to `erlang:system_time(millisecond)`, which inside a fight loop destroys reproducibility. It becomes the tick. Inside the loop it is a record, not a map with atom-or-binary key tolerance |
| `remote_id_sensor_model`'s structure | **ports.** Presence, range, probability, noise, confidence |
| ... its arithmetic | **does not port.** `math:sqrt`, `rand:uniform/0`, `rand:normal/0` and floats. The fight path is integer and seeded, so all three need replacing |
| `on_contact_observed_correlate_track` | **nothing to port.** Its own docstring says "the SKELETON minimum", and `TrackId = <<"track-", DroneId/binary>>` shows why: the correlation is string concatenation on the drone's **self-reported identity**. That works only for Remote-ID and is meaningless for any sensor that does not hand you an id |
| `maybe_confirm_track` | **nothing to port.** A one-shot idempotence guard, not an evidence accumulator. No threshold, no voting, no track-lost |
| the architectural separation | **ports, and it is the point.** Sensors produce contacts, something else turns contacts into tracks, and the consumer never learns which sensor produced what |
| bit-flag track status | **ports.** `evoq_bit_flags` is the house rule for status fields anyway |

**So the track algorithm has to be written**, and for a counter-drone network it
is well understood and small: associate a contact to an existing track by
predicted position with a gate, accumulate evidence, confirm above a threshold,
drop after N ticks without an update.

⚠ **And the CQRS wrapper does not come with it.** Contacts and tracks inside an
engagement are terms in a fold. Nothing writes an event, nothing dispatches a
command, nothing touches the store or the mesh during a fight. The retired
per-drone aggregate cost one store write per reposition, and that judgement
stands unchanged.

## The confirmation threshold is the interesting number

Evidence-to-confirm is one integer and it is the real counter-UAS tradeoff:

- **too sensitive** and the network cues its drones at ghosts, and they spend
  battery flying at nothing
- **too conservative** and it sees the attacker too late to launch

There is a real optimum and it depends on what is attacking you, which means it
is worth evolving and it is cheap to evolve. It becomes part of the island's
persisted state.

## Staging, because this roughly doubles the build

| phase | what | why here |
|---|---|---|
| **1** | one non-cooperative modality, fixed placement, fixed threshold, the ground bank, the three-way ablation | the smallest thing that makes the asymmetry real and measurable |
| **2** | the confirmation threshold evolves | one integer, and it is the genuine tradeoff |
| **3** | placement evolves, is persisted, is published, is drawn | this is what makes islands visibly different places |
| later | Remote-ID as the friendly-tracking modality; more modalities; destructible sensors | each adds an axis, none is needed to make the thing work |

## What the map gains

The map stops drawing an empty volume with marks in it.

- **coverage**, as a soft footprint per sensor, so blind corridors are visible
- **a raid arriving**, threading the gaps or failing to
- **a track being confirmed**, as the moment the defender knows
- **the ground bank transmitting**, as pulses from the ground, so *the network
  has seen them* is a thing a viewer watches rather than reads

Two islands then look different at a glance, which is the thing an archipelago
map has never been able to show.
