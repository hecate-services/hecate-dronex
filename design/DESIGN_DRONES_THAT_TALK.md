# Drones that talk

**This exists so a swarm can be more than the sum of the drones in it, and so
that whether it actually is can be measured rather than admired.**

---

## Why this is not walking back into a closed programme

Programme P7 closed on a negative and the charter says so. It is worth being
precise about what it closed, because this document could otherwise look like a
rerun.

**P7 asked about escalation between two adapting sides**: does an arms race
happen, does the interaction cycle, does a co-adapting opponent buy anything a
diverse static one does not. The answers were no, no, and no, at four speed
brackets and reproduced at n=80.

**This asks about coordination inside one side.** That is a cooperation
question, with different literature, different failure modes and different
null results. The nearest relevant prior work is the evolution of signalling
under conflicting interests, where the interesting finding is that public
signals with divergent interests select for **information suppression** rather
than for richer language.

Nothing in P7 speaks to it, so this is new ground rather than a repeat.

## Four decisions, each of which could ruin it

### The channel is uninterpreted

Four integers out per drone per tick, four in. **Nothing declares what they
mean.**

The tempting alternative is a channel that carries something named, "my
position" or "target bearing". That is a hand-coded tactic with evolution
reduced to tuning its gain, and it forecloses the only interesting outcome. What
a signal means is decoded afterwards, by correlating it against everything else
in the frame, and if it correlates with nothing then nothing was being said.

⚠ Charter rule 8, restated: **no channel may name a tactic.** This is where the
rule bites hardest, because a named channel here would be the most natural thing
in the world to write.

### Aggregation is permutation-invariant, and it is a sum

N transmissions have to become a fixed-width input. The options and why the
third wins:

| | |
|---|---|
| fixed slots per drone index | breaks the moment a drone dies, and ties a controller to a swarm size |
| mean over everything heard | invariant and lossy: it throws away **how many** are transmitting |
| **sum over everything heard, clamped** | invariant, fixed width whatever the swarm size, degrades gracefully as drones die, and the magnitude carries a crude count |

The sum matters more than it looks. It means **one population of genomes flies
as a swarm of four or a swarm of twelve** without per-slot specialists, which the
roster model needs: a sortie is drawn from the roster, not assembled from
declared roles.

### One tick of latency, and a range limit

Zero latency is not communication, it is a shared brain. With a tick of delay a
signal is necessarily **about the past**, which is what makes acting on it a
problem worth solving and what makes memory in the controller load-bearing.

Range is what makes position and formation matter. A drone that flies away from
its swarm goes quiet to it, which is a cost nobody had to design.

```
comms range      300 m
latency          1 tick (50 ms)
channels         4 out, 4 friendly in, 4 hostile in
```

### The enemy hears you

Two banks in, friendly and hostile, so a drone knows which side a transmission
came from but not which drone.

**This is what makes it tactics rather than telemetry.** Signalling becomes a
trade between coordinating with your own side and disclosing to the other, and
neither term is free. A swarm that goes silent under contact has discovered
something; so has one that transmits harder.

⚠ **Separate banks first, deliberately, and the merged version is a later
experiment.** With separate banks a drone can always tell friend from foe, so
there is disclosure pressure but no **deception** pressure. Merging the banks
into one, so that a transmission's origin is not given, is what would make
transmitting something misleading a strategy. That is the richer version and it
is also much harder to get anywhere from, so it is named here and not built.

## The instrument, in the same commit as the channel

⚠ **This is not a follow-up and it is not optional.** Without it, "the drones
coordinate" is an impression produced by watching, and a rising fitness in a
population that has a channel says nothing about whether the channel is why.

**The ablation.** Replay a published fight, unchanged in every other respect,
with both incoming banks forced to zero. The delta in the outcome is the
measurement. It is cheap because the replay machinery exists anyway, it is
exact because the engine is deterministic, and it is impossible to add to
history later.

Three numbers are published from every island:

| number | what a zero means |
|---|---|
| **signal volume per engagement** | nothing was ever transmitted, and every claim about coordination for that period is void rather than null |
| **ablation delta** | the channel is being driven but nothing depends on it |
| **channel entropy** | the channel is being driven with a constant, which is silence wearing a signal's clothes |

Charter rule 4 applies to all three: publish the exercise count beside the null.
A run where the ablation was never performed and a run where it came back zero
must not look the same.

## What is worth measuring later, borrowed rather than invented

`faber-neuroevolution` has a `communication_silo`, and it is worth being clear
about what it is: a **tracker**, not a transport. `send_message/4` is a
`gen_server:cast` that records statistics for the meta-controller; it carries
nothing between evolved agents and it is not the substrate here.

But somebody already worked out what to measure about evolved signalling, and
that list is the instrument spec for later work: vocabulary size, dialect
formation, coordination success, and honesty against deception dynamics. Taken
as design, not as code.

**Dialect is the one that becomes interesting on this substrate specifically.**
Raids hand genomes across the mesh, so an island that raids constantly also
publishes its signalling convention. Whether islands drift into private
conventions, and whether a captured genome carries a protocol its captor cannot
use, is an emergent consequence of the raid design rather than a mechanism to
build. It is watched for; it is not implemented.

## What this rules out

**No addressing.** A drone cannot transmit to a particular other drone. Adding
one would make coordination a routing problem rather than a signalling one.

**No bandwidth beyond four channels.** A wider channel is a wider input layer
with extra steps, and the interesting result is about what evolves inside a
narrow one.

**No transmission cost in battery.** Real radio costs a rounding error next to
flight, and inventing a number would be a physics constant nobody measured. The
cost of transmitting is strategic, which is disclosure, not energetic.
