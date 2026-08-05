# Charter: a virtual environment for potentially real-world drone AI

**This exists so a swarm bred on one machine can attack a swarm bred on another,
and so the controller that wins can leave the simulator and fly.**

Opened 2026-08-05. It replaces this repository's counter-UAS airspace-fusion
line, which is not deleted and not abandoned: it is the second act, and what
survives of it is stated in
[DESIGN_THE_SECOND_ACT.md](design/DESIGN_THE_SECOND_ACT.md).

**This is the front door. It states what this track is committed to.**
[`design/`](design/) says why, one document per topic, each carrying its own
reasoning. If you want to argue with a decision, argue with the document that
made it.

---

## CLASSIFICATION: this is a BUILD

Stated first and out loud, because `CLAUDE.md` requires it and because the
alternative reading is expensive.

**Nothing here tests a hypothesis about the world.** It is a simulator, an
evolutionary substrate, a mesh protocol and an exhibit. It gets tests and a
commit. It gets no pre-registration and no adversarial design gate.

⚠ **And there is one specific claim it must not drift into making.** Programme
P7 in `faber-ecosystem` closed on a negative at insight 062, and its arc-level
result is *every configuration tested was either too decoupled to escalate or
too coupled to survive, with no lever between the two*. 057 refuted reciprocal
coupling twice, reproduced at n=80 and again on a re-implemented engine: a
co-adapting opponent buys nothing a **diverse static** one does not.

So **"the islands arms-raced" is a sentence this repository may not write**
without a pre-registration, a graded benchmark and a master tournament, which is
the toolkit signed at 053 to 056. What it may write is what the design is
actually built on, below.

## The one idea

Take 057 literally rather than as a discouragement.

If a co-adapting opponent buys nothing that a diverse static one does not, then
**a raid is not how fitness is assigned. A raid is how opponent diversity
crosses the mesh.**

Selection stays local, against a set of opponents that raids make wider. An
island that has been attacked holds genomes it could not have invented, and
those genomes are what its own population then has to beat. That is a use of
coevolution which survives P7's negative instead of contradicting it, and it is
the reason this track is worth building at all.

Everything else follows from it.

## What an island is

One node runs one island. An island holds:

- a **roster** of persisted drone genomes, finite and contested
- an **opponent set**: scripted drills, its own past champions, and every
  foreign genome it has ever been attacked by
- a **trainer**, always running, breeding against the opponent set
- a **frozen benchmark** it never trains against, which is the only number on
  this island that may be called improvement
- an **airspace**, where fights happen

An island **hosts the fights it is attacked in**. It spends its own CPU and its
own airframes, and what it gets for that is the attacker's genomes.

## What is committed to

| commitment | where it is argued |
|---|---|
| **The airspace is continuous, not a lattice.** Fixed-point 3D, gravity, thrust, drag and a battery. No hexes, no cells, no stepping | [DESIGN_THE_AIRSPACE.md](design/DESIGN_THE_AIRSPACE.md) |
| **A drone is a body, a fixed sensor suite and an evolved brain.** The perception boundary is a shape the compiler checks, not a comment | [DESIGN_THE_DRONE.md](design/DESIGN_THE_DRONE.md) |
| **Drones talk, and what the signal means is evolved.** Range-limited, one tick late, permutation-invariant, and the enemy hears it | [DESIGN_DRONES_THAT_TALK.md](design/DESIGN_DRONES_THAT_TALK.md) |
| **A genome is spent when it flies.** The roster is finite, raids cost airframes, and rebuilding costs ticks | [DESIGN_THE_ROSTER_AND_THE_RAID.md](design/DESIGN_THE_ROSTER_AND_THE_RAID.md) |
| **The defender hosts, and keeps what attacked it.** Requests come in on the fleet realm, facts go out on a public one | [DESIGN_WHAT_CROSSES_THE_MESH.md](design/DESIGN_WHAT_CROSSES_THE_MESH.md) |
| **A raid is a recording, published once and played locally.** The site draws frames it was handed and computes nothing | [DESIGN_THE_MAP.md](design/DESIGN_THE_MAP.md) |
| **The world is ours, the neural substrate is a library.** What is in this repo and what is `faber_tweann`, and why the line falls there | [DESIGN_WHAT_WE_TAKE_FROM_FABER.md](design/DESIGN_WHAT_WE_TAKE_FROM_FABER.md) |
| **The counter-UAS line is the second act.** What is kept, what is retired, and where the swap point moved to | [DESIGN_THE_SECOND_ACT.md](design/DESIGN_THE_SECOND_ACT.md) |

## What is given, and what must emerge

**Given**, said out loud because it is scaffolding: the flight physics, the
sensor channels and their meaning, the actuator channels, the comms channel
width and its range, the battery economy, the arena, the scripted drills, the
start geometries, the roster capacity, and the fact that raids happen at all.

**Emerges:** every tactic. What a signal means. Whether signalling is used at
all. Formation, if there is one. Whether a swarm splits, screens, baits or
converges. Whether islands specialise into attackers and defenders. Which
lineages spread across the archipelago and which die at home.

⚠ **Nothing in the sensor list names a tactic.** There is no "am I flanking"
channel and there will not be one. The first bespoke channel is a tactic
arriving through the implementation, which is this repository's version of the
sibling's rule 8.

## The instruments, named before the mechanisms

| instrument | answers |
|---|---|
| **frozen benchmark score** | did this island get better. The ONLY improvement number |
| **signal volume per engagement** | was anything ever transmitted. Zero invalidates any claim about coordination |
| **comms ablation delta** | replay the same fight with both channel banks zeroed. Without this, "they coordinate" is an impression |
| **roster depth and generation** | how deep the lineage is, and how ground down |
| **opponent-set composition** | how much of what this island trains against came from somewhere else |
| **foreign lineage share** | how much of the archipelago's genetic material has crossed at least one border |
| **sortie survival rate** | attacker and defender, separately |
| **behaviour archive size** | how many distinct tactics have ever been seen here. The operational measure of whether this is still discovering |

⚠ **The frozen benchmark is not optional and cannot be retrofitted.** A
population evolving against a widening opponent set shows a rising local fitness
that means nothing, because the exam is changing underneath it. Insight 054 is
exactly this failure. The benchmark is a fixed set of scripted drills over a
fixed set of start geometries, never trained against, run on a timer and
published from the first commit.

## The rules this track runs under

1. **CLAIM or BUILD, decided out loud before the work starts.** Everything in
   the order of work below carries its classification. A BUILD never gets a
   gate; a CLAIM never skips one.
2. **The physics ship with the image.** A node config may name what a node **is**:
   its island name, its door, its seed, its pace. It may never name what the
   physics **are**. The predecessor put two of three fleet nodes into a
   boot-crash loop by keeping an economy constant in a deployment repo on a
   different release cadence.
3. **A constant is chosen on viability, never on outcome.** Publish the whole
   sweep, including the arms that killed everything.
4. **A capacity that was never exercised is not evidence of anything.** Publish
   the exercise count beside every null. An island that has published nothing
   and an island whose every publish failed look identical in a log.
5. **A guard compares two sides of a boundary.** A field computed and never put
   on a wire is the failure mode that costs the most and shows the least.
6. **Anything read off a wire gets a test that pushes the real message through
   the real handler.** `I.26` on the sibling: a four-tuple match against a
   five-element SDK message discarded every fact for an hour, with 226 published
   and 0 failed at the other end.
7. **Real quantities, in real units.** Metres, metres per second, seconds,
   watt-seconds. Fixed-point representation is an implementation detail; a
   quantity with no unit is a quantity that cannot leave the simulator, and
   leaving the simulator is the point.
8. **No sensor channel may name a tactic.**
9. **Nothing is deleted to make room.** The counter-UAS line is kept as the
   second act, marked, not quietly removed.
10. **Every register entry carries an ELI5 section**, written in the same commit
    by whoever wrote the entry. An explanation written elsewhere and afterwards
    is a translation, and translations drift.

## Vocabulary

- A machine runs an **island**. An island has a **name**, which an operator
  types and two islands can share, and an **identity**, which is 128 bits nobody
  types. They are not the same thing and conflating them breaks four things at
  once. See `DESIGN_WHAT_CROSSES_THE_MESH.md`.
- An island holds a **roster** of **genomes**. A genome is a controller: a
  topology and its weights.
- A genome that is flying is a **drone**. A group of them in one engagement is a
  **swarm**.
- One engagement between an attacking swarm and a defending swarm is a **raid**.
  The attacker's drones are its **sortie**.
- A genome that has survived a raid is a **veteran**.
- A human being who runs a node is an **operator**, never a pilot.

**A drone, not a tank and not a creature.** In 2026 a drone is airborne, and the
noun has to carry that or the physics will drift back to the ground.

## Order of work

| # | work | kind | why here |
|---|---|---|---|
| 1 | the hecate_om spine: service, mesh, identity, facts, server, store, container, CI | **BUILD** | the tedious end is finished before the interesting end starts, so no increment waits on plumbing. Copied in shape from `hecate-society` |
| 2 | the airspace: flight, battery, hits, the arena, determinism | **BUILD** | everything stands on it |
| 3 | the drone: sensors, actuators, the brain, the genome wire form | **BUILD** | |
| 4 | the frozen benchmark: scripted drills, fixed starts, the published score | **BUILD**, before any breeding | rule: a rising number against a moving exam is an artifact, and it cannot be added to history later |
| 5 | the trainer and the roster, persisted | **BUILD** | |
| 6 | comms, with the ablation instrument in the same commit | **BUILD** | the instrument is not a follow-up. Without it the channel is decoration |
| 7 | the raid protocol, and the defender keeping what attacked it | **BUILD** | |
| 8 | the map | **BUILD** | |
| 9 | ONNX export of a champion, flown against the simulator through the exported artifact | **BUILD** | this is what makes the framing true rather than aspirational, and it is a test rather than a claim |

**No claim is scheduled.** If one is ever wanted, it goes in `claims/` with a
pre-registration, and the four measurement rules from 053 to 056 apply.

## Owed before anything is called finished

- **A ruling on what a returning veteran carries.** With in-flight plasticity a
  drone can come home with different weights from the ones it took off with.
  Storing the returned weights is **Lamarckian inheritance**, and that is a real
  and deliberate choice rather than an accident. Argued in
  [DESIGN_THE_ROSTER_AND_THE_RAID.md](design/DESIGN_THE_ROSTER_AND_THE_RAID.md);
  both arms must be runnable.
- **Trust.** An island identity is 128 bits nobody signs, so it defeats accident
  and not impersonation. A hostile node can claim to be another island and can
  submit pathological genomes. Validation limits are a denial-of-service defence
  and are in scope; identity signing is named here and is not.
- **Determinism across machines.** The pure-Erlang fight path must be
  bit-identical on different hardware, which needs a table activation rather
  than libm. Until that lands, replay agreement is a property of the fleet
  running one image, not of the design.
- **What a defender owes an attacker.** Today the defender reports the outcome
  and is believed. The engine is exactly replayable by design, so the attacker
  can check; nothing yet requires it to.

## What carries across from the siblings

**Carried in code**, copied rather than extracted, because two consumers is a
copy: the island name against island identity split, the module that is the only
one to know macula exists, the facts module that is pure and owns the topics,
the two-timer server, the counted-and-shrugged-at publish failure.

**Carried as discipline:** the register including entries about how the work
itself went wrong, the ELI5 rule, boundary guards, and stating the negative in
advance.

**Dropped:** event sourcing of the world. The sibling's own note says it best:
the island lives in a `gen_server` and is not event-sourced, and what the store
holds is what an island **found**. Here that is the roster, which is exactly the
right thing to keep and the wrong thing to replay.
