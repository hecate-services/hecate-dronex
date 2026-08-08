# Charter: a virtual environment for potentially real-world drone AI

**This exists so a swarm bred on one machine can attack a swarm bred on another,
and so the controller that wins can leave the simulator and fly.**

Opened 2026-08-05. This repository's counter-UAS airspace-fusion line is neither
deleted nor deferred: **its detection layer becomes an island's static defence
network**, which is what makes attacking harder than defending. See
[DESIGN_THE_STATIC_DEFENCE.md](design/DESIGN_THE_STATIC_DEFENCE.md) for the
design and [DESIGN_THE_SECOND_ACT.md](design/DESIGN_THE_SECOND_ACT.md) for what
of that line is retired and what stays deferred.

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
- an **opponent set**: the **curriculum** drills (`drone_drills`), its own past
  champions, and every foreign genome it has ever been attacked by
- a **trainer**, always running, breeding against the opponent set
- a **held-out benchmark** it never trains against (`drone_trials`), which is the
  only number on this island that may be called improvement

⚠ **THE TWO SETS OF SCRIPTED OPPONENTS ARE DIFFERENT SETS, AND FOR MONTHS THEY
WERE ONE.** These two bullets were both right and were served by the same six
behaviours, so the exam sat inside its own training distribution: `REGISTER
I.22`. The separation is now enforced by `trials_tests`, which fails if any exam
rung appears in `trainer:opponents/1`. Nothing about this is guaranteed by the
two sentences above, which is the whole lesson.
- an **airspace**, where fights happen
- a **static defence network**: ground sensors with real coverage and real
  blind spots, which transmit what they detect

An island **hosts the fights it is attacked in**. It spends its own CPU and its
own airframes, and what it gets for that is the attacker's genomes.

**You fight at home with your network, and away without it.** An island's
sensors defend its own airspace only, so raiding means giving up the thing that
makes you strong. That is the asymmetry the whole game turns on, and it is why
attack and defence can become good at different things rather than converging on
one behaviour.

## What is committed to

| commitment | where it is argued |
|---|---|
| **The airspace is continuous, not a lattice.** Fixed-point 3D, gravity, thrust, drag and a battery. No hexes, no cells, no stepping | [DESIGN_THE_AIRSPACE.md](design/DESIGN_THE_AIRSPACE.md) |
| **A drone is a body, a fixed sensor suite and an evolved brain.** The perception boundary is a shape the compiler checks, not a comment | [DESIGN_THE_DRONE.md](design/DESIGN_THE_DRONE.md) |
| **Drones talk, and what the signal means is evolved.** Range-limited, one tick late, permutation-invariant, and the enemy hears it | [DESIGN_DRONES_THAT_TALK.md](design/DESIGN_DRONES_THAT_TALK.md) |
| **An island is a place with coverage and blind spots.** Ground sensors are terrain, they cue by transmitting rather than by privileged input, and you fight at home with them and away without | [DESIGN_THE_STATIC_DEFENCE.md](design/DESIGN_THE_STATIC_DEFENCE.md) |
| **A genome is spent when it flies.** The roster is finite, raids cost airframes, and rebuilding costs ticks | [DESIGN_THE_ROSTER_AND_THE_RAID.md](design/DESIGN_THE_ROSTER_AND_THE_RAID.md) |
| **The defender hosts, and keeps what attacked it.** Requests come in on the fleet realm, facts go out on a public one | [DESIGN_WHAT_CROSSES_THE_MESH.md](design/DESIGN_WHAT_CROSSES_THE_MESH.md) |
| **A raid is a recording, published once and played locally.** The site draws frames it was handed and computes nothing | [DESIGN_THE_MAP.md](design/DESIGN_THE_MAP.md) |
| **The world is ours, the neural substrate is a library.** What is in this repo and what is `faber_tweann`, and why the line falls there | [DESIGN_WHAT_WE_TAKE_FROM_FABER.md](design/DESIGN_WHAT_WE_TAKE_FROM_FABER.md) |
| **The counter-UAS line comes forward, minus its machinery.** What is retired, what stays deferred, and the two seams the swap point now sits on | [DESIGN_THE_SECOND_ACT.md](design/DESIGN_THE_SECOND_ACT.md) |

## What is given, and what must emerge

**Given**, said out loud because it is scaffolding: the flight physics, the
sensor channels and their meaning, the actuator channels, the comms channel
width and its range, the battery economy, the arena, the scripted drills, the
start geometries, the roster capacity, the ground sensor model and that a
defence network exists at all, and the fact that raids happen.

**Emerges:** every tactic. What a signal means. Whether signalling is used at
all. **Whether a cue from the ground is used, and whether an attacker learns to
hear that it has been seen.** Approach paths through gaps in coverage.
Formation, if there is one. Whether a swarm splits, screens, baits or converges.
Whether islands specialise into attackers and defenders. Which lineages spread
across the archipelago and which die at home.

⚠ **Nothing in the sensor list names a tactic.** There is no "am I flanking"
channel and there will not be one. The first bespoke channel is a tactic
arriving through the implementation, which is this repository's version of the
sibling's rule 8.

## The instruments, named before the mechanisms

| instrument | answers |
|---|---|
| **frozen benchmark score** | did this island get better. The ONLY improvement number |
| **signal volume per engagement** | was anything ever transmitted. Zero invalidates any claim about coordination |
| **comms ablation delta, three ways** | replay the same fight with the air banks muted, the ground bank muted, and all three muted. Without this, "they coordinate" and "they were cued" are one impression |
| **detection latency and leakage** | how far in did an attacker get before it was tracked, and how often did a sortie cross uncued |
| **raid success rate, home against away** | the asymmetry, measured. It is also the viability gate: if attacking never works, nothing crosses and the archipelago is four experiments again |
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

⚠⚠ **And it is an away game, always: no sensors, no cueing, ground bank forced
to zero.** Otherwise an island that improved its **fortifications** would show a
rising benchmark, and that number would not be about its drones at all. The
defence network is measured separately and the two are never added together.

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

| # | work | kind | done | why here |
|---|---|---|---|---|
| 1 | the hecate_om spine: service, mesh, identity, facts, server, store, container, CI | **BUILD** | ✅ | the tedious end is finished before the interesting end starts, so no increment waits on plumbing. Copied in shape from `hecate-society` |
| 2 | the airspace: flight, battery, hits, the arena, determinism | **BUILD** | ✅ | everything stands on it |
| 3 | the drone: sensors, actuators, the brain, the genome wire form | **BUILD** | ✅ | |
| 4 | the frozen benchmark: scripted drills, fixed starts, the published score | **BUILD**, before any breeding | ✅ | rule: a rising number against a moving exam is an artifact, and it cannot be added to history later |
| 5 | the trainer and the roster, persisted | **BUILD** | ✅ | |
| 6 | comms, with the ablation instrument in the same commit | **BUILD** | ✅ | the instrument is not a follow-up. Without it the channel is decoration. Four channels, three banks, one tick late, summed. `ablation` ships in the same commit and its three numbers are on every vitals fact |
| 7 | the raid protocol, and the defender keeping what attacked it | **BUILD** | ✅ | availability by pubsub (`opened`/`closed`), the handshake by RPC, both sides emitting `committed`, settlement back to the attacker. Proven end to end on two islands |
| 8 | **static defence phase 1**: one non-cooperative modality, fixed placement, fixed confirmation threshold, the ground bank, the three-way ablation | **BUILD** | ✅ build, ⏳ sweep | the smallest thing that makes the asymmetry real. It lands before the map so coverage is drawn from the start rather than retrofitted. **The viability sweep is owed** — see below |
| 9 | the map | **BUILD** | ✅ | the archipelago with raid arcs, and the fight drawn obliquely with trails |
| 10 | **static defence phase 2**: the confirmation threshold evolves | **BUILD** |  | one integer, and it is the genuine counter-drone tradeoff: cue at ghosts and waste battery, or see too late |
| 11 | **static defence phase 3**: placement evolves, is persisted, is published, is drawn | **BUILD** |  | this is what makes islands visibly different places |
| 12 | ONNX export of a champion, flown against the simulator through the exported artifact | **BUILD** |  | this is what makes the framing true rather than aspirational, and it is a test rather than a claim |

⚠ **Items 8, 10 and 11 are staged deliberately**, because the static defence
roughly doubles the surface of the build and only phase 1 is needed for the game
to be a game.

⚠⚠ **ITEM 8 OWES A VIABILITY SWEEP AND IS NOT FINISHED WITHOUT IT.** The criterion
was written down before the dial was set, which is the only order in which it
means anything: **a competent attacking swarm must win a non-trivial fraction of
raids against a competent defence.** If home advantage turns out to be
overwhelming, every island turtles, nothing raids, no genomes cross, and the one
idea this repository has dies quietly while the exhibit still looks busy.

The sweep turns sensor count and sensor range. The whole sweep gets published,
**including the settings that made attacking hopeless** — charter rule 3, and the
standing rule that a dial is never set by which value gave the answer that was
wanted.

⚠⚠⚠ **AND THE SWEEP HAS FIVE DIALS, NOT ONE.** It was named as station count.
Three more were found by building the instruments rather than by thinking:
**reach against the geometry a fight starts in** (D.13 — every raider is
confirmed on frame 1, so there is no approach phase to measure), the **ceiling**
(D.12 — a station's radius at altitude is sqrt(R² - z²), so the ceiling is a
coverage parameter), and the **gun's blast radius and magazine**
([DESIGN_THE_SECOND_WEAPON.md](design/DESIGN_THE_SECOND_WEAPON.md)). A sweep
over station count alone would have measured a saturated network at every point
and reported a smooth, confident, meaningless curve.

The harness is **built and unrun**: `scripts/sweep_the_defence.sh` recompiles the
physics per arm and `scripts/is_raiding_viable.escript` measures one arm, with
the criterion fixed above the code before any of it runs. Dials 4 and 5 are
declared and skipped loudly rather than quietly omitted; they become live by
adding values when the second weapon lands.

It is owed rather than done because it cannot be run yet: a sweep against
untrained rosters measures random controllers, not competence, and would answer
a different question convincingly. It runs once the fleet's rosters have trained
under the towers, which is the first generation that could possibly learn to use
a cue that until now was four zeroes.

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
- ⚠ **Bit-identical replay across runtimes is NOT a commitment, decided
  2026-08-05.** `network_evaluator:apply_activation/2` is private with a closed
  clause list and a catch-all of `math:tanh(X)`, so there is no way to put a
  table activation in front of it, and the choice taken was to keep faber's
  evaluator with its CfC memory, plasticity and NIF. The **arena** stays integer
  and exact, so divergence is confined to one function and bounded at about a
  unit in the last place; the fleet runs one image, so replay works today. What
  is owed is that the engine fingerprint on a raid request name the OTP release
  and the libc, not only the code.
- **What a defender owes an attacker.** The defender reports the outcome and is
  believed. An attacker on a matching runtime can replay and expect agreement,
  and cannot demand it otherwise, so this is reporting rather than proof. Making
  it proof would need the brain to be exact, which is the trade above.
- **Whether the home advantage leaves room to attack.** Stated as a viability
  criterion rather than assumed: a competent attacking swarm must win a
  non-trivial fraction of raids against a competent defence. If it cannot,
  islands turtle, no genomes cross, and the one idea dies while the exhibit
  still looks busy. Network strength is set on that measurement, whole sweep
  published.

  ⚠ **ITS STATED BLOCKER HAS PLAUSIBLY LIFTED, 2026-08-07.** The sweep was
  written as unrunnable because "a sweep against untrained rosters measures
  random controllers", and it needed the first generation that could have learnt
  to use a cue that until then was four zeroes. The fleet has now been breeding
  under the towers for days and the ground bank is live and measured — see the
  coverage figure below. Whether the sweep can run is now a question to ask
  rather than a settled no.

- ⚠ **`REGISTER I.21` MOVES EVERY MEASUREMENT TAKEN BEFORE 2026-08-07 ONTO
  UNCERTAIN GROUND.** `roster_log:restore/2` had never succeeded, so every island
  began from seed on every deploy. Anything read off this fleet that assumed a
  lineage older than the last container recreate was reading a younger population
  than it thought. Fixed the same day; nothing measured before it should be
  quoted without saying which side of it the measurement falls on.

- **Why the frozen exam swings by a hundred points in a day.** `REGISTER D.15`.
  `beam03` went 288/288 → 1/288 → 27% → 86% while the fleet sat between 87% and
  99%, and `benchmark_sitter` says its champion was **bred** every time, which
  kills the obvious explanation. Until this is understood, no reading of the exam
  as a measure of progress is safe, and the leaderboard's headline column is a
  number nobody can interpret. ⚠ `I.21` supplies a candidate the entry could not
  have had: the champion may have been bred from scratch that morning, because
  the roster had not survived the night's deploy.

- **A ram cannot be told from the arena edge, and that is a WIRE limit.** The
  damage accounting separates weapon damage exactly, because `HIT_DAMAGE` and
  `INTERCEPTOR_DAMAGE` are exact multiples of 100 of a 10000 start and the
  quantum survives fractional health. It cannot split the remainder, because
  confirming a collision means finding another drone within `2 × DRONE_RADIUS` —
  one metre — and frames publish **whole metres**. At that resolution "touching"
  and "two metres apart" read the same. Two ways out, and the second is cheaper
  and exact: publish sub-metre positions, or give `hurt/2` a damage SOURCE
  instead of one accumulator.

  Measured meanwhile, over every raid the exhibit has seen: **about 80% of all
  damage is weapon-quantised.** These are fights. Self-inflicted attrition is a
  real minority rather than the story.

- **What the towers hold, now measured for the first time.** `REGISTER D.12`
  claimed height buys silence and nothing had ever checked it. Over 1,136
  raider-frames: 23% of time held at 0–50 m, falling monotonically to 0% above
  250 m. ⚠ It is a **ceiling** — tracks carry no id by construction, so this
  counts a track existing within 25 m of a raider, and two raiders flying
  together are both covered by one track.

- **Whether the radio does anything, still unanswered.** The ablation is the only
  causal instrument this repository owns: same genome, same opponents, one
  channel silenced. Its deltas are currently inconsistent in sign across islands
  AND across arms, at a resolution where one engagement changing hands moves the
  number 25 points. One exercise cannot settle it and neither can two. What
  settles it is the same number drifting off zero across many, which needs the
  measurement accumulated rather than republished.

- ⚠ **The recordings the exhibit reasons over are a ROLLING WINDOW.** They are
  whatever arrived and survived a row cap, not a sample anybody chose. Fine for
  an exhibit; if any figure here ever hardens into a claim, the retention is a
  selection effect and the claim gate starts there.

- ⚠ **THE FROZEN LADDER NEEDS HARDER RUNGS, OR IT IS DECORATION.** `REGISTER
  D.16`: once lineages survived a restart, the fleet cleared every drill at 99%
  within about a day. Four of five islands sit at 47 or 48 of 48 on all six, so
  the one absolute measure this project has now discriminates a single island and
  nothing else, and the leaderboard's headline column has a fleet-wide spread of
  two points. The drills are named and ordered, so the shape of the extension is
  obvious: the deficit that survives is against opponents that shoot AND close.

  ⚠ **DONE 2026-08-08, and it turned out to be the same fix as a defect nobody
  had noticed.** `drone_trials` is a held-out ladder of six opponents that shoot
  AND close, each the chaser plus exactly one competence. Champion totals span
  120 to 276 of 288 against this ladder's spread of two points. It is graded
  against the fleet's own champions, its rung order is measured rather than
  asserted, and `I.23` states where it is blind: three of eight random
  controllers still sweep the bottom four rungs, so the resolution lives in
  `swooper` and `leader`.

  **What is still owed here:** the held-out profile is computed but not yet
  published, so no island reports it and the exhibit cannot draw it. That is a
  fact version bump and a read model, not a science question.

- ⚠ **AN INSTRUMENT PROMISED IN FOUR DOCUMENTS AND ENFORCED IN NONE.** `REGISTER
  I.22`. The exam was six of the opponents the trainer breeds against, between
  about 11% and 28% of rounds per island, and had been since the trainer was
  written. Fixed by separating the ladders and by a test that fails if they ever
  merge again.

  **What is owed is not the fix but the audit it implies:** every other property
  this charter promises in prose should be asked the same question, which is
  whether anything in the code would notice if it stopped being true. The two
  obvious candidates are "it is an away game, always" and "nothing is tuned on
  what a diagnostic prints".

- **Whether msi00's two anomalies are one anomaly.** It has bred 50% more than
  any beam node, is alone in failing `chaser` and `duellist`, and is the only
  island whose radio ablation has never gone positive. It is also the only
  machine that is not a beam node and the only one running podman. Three thin
  threads: more breeding with worse closing performance, a channel that never
  costs anything to silence, and a different host. Any two of them being the same
  story would be worth knowing.

- **`REGISTER.md` has passed the size at which its own rule says to split it.**
  The file states "one file until it passes about 800 lines, then one file per
  series under `register/`". It is past 1,400.

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
