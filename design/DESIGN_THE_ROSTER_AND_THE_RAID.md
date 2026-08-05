# The roster and the raid

**This exists so an island is a lineage rather than a run, and so that losing a
raid costs something.**

---

## The loop, whole, before any of the parts

```
roster  (persisted, finite, contested)
   |
   |--- TRAIN, locally and always, against the OPPONENT SET
   |      opponent set = scripted drills
   |                   + this island's own past champions
   |                   + every foreign genome that has ever attacked it
   |      selection + variation -> candidates -> admitted or refused
   |
   |--- BENCHMARK, on a timer, against a FROZEN set never trained on
   |      the only number that may be called improvement
   |
   |--- RAID: N genomes leave the roster and fly.
   |      survivors return. The dead do not.
   |      rebuilding means breeding, which costs ticks.
   |
   '--- DEFEND: M genomes leave the roster and fly.
          losses are equally real
          and the attacker's genomes are KEPT, entering the opponent set
```

⚠ **Fitness is never assigned by a raid.** Selection is local, against a set
that raids make wider. That is the charter's one idea and this is where it is
mechanical: insight 057 says a co-adapting opponent buys nothing a diverse
static one does not, so raids are built as a **diversity pump for the training
curriculum** rather than as a selection pressure. Wiring raid outcomes directly
into fitness would be building the thing that was refuted.

## The roster

Finite, and the finiteness is the whole point.

```
capacity   240 genomes
```

An entry:

```erlang
#genome_record{
    id,              %% sha256 of the packed genome
    layers, weights, %% the genome itself, quantized
    born_at,         %% tick
    generation,
    parents,         %% [id]
    origin,          %% {bred, IslandId} | {captured, IslandId, RaidId}
    sorties,         %% times flown
    returns,         %% times it came home
    veteran_of       %% [{IslandId, RaidId, Tick}]
}
```

**Persisted from the first commit**, in the reckon-db store the service opens.
The sibling's argument for having a store applies here more directly than it did
there: what the store holds is what an island **found**, and a trained swarm is
expensive to produce. An island that loses its roster on every container
recreate is a recording of its own first ten minutes.

⚠ **The moment `store_id/0` and `data_dir/0` are exported, `sys.config.src` must
carry the `evoq` block.** `hecate_om` starts a per-store evoq subscription that
reads the global log and crashes on `{not_configured, event_store_adapter}`
without it, before any service code runs, so nothing can inject it later. This
put two of three fleet nodes into a boot-crash loop on a sibling.

⚠ **And the island's 128-bit identity lives in the same directory.** A
deployment that forgets the bind mount does not merely lose the roster: the
island becomes a **new island** at every restart and every fact it ever
published is orphaned.

## A genome is spent when it flies

The single rule that gives a raid a price.

Sending twelve drones **removes twelve entries from the roster**. Survivors are
returned to it, the dead are not, and refilling the gap means breeding, which
costs ticks the trainer would otherwise have spent improving.

Without this, a defeated attacker rebuilds from the archive at no cost, and the
exhibit becomes islands raiding, losing, rebuilding and raiding again while
nothing selects. That is stasis wearing the costume of activity, and it is the
failure this design is most at risk of.

It also happens to be what a 2026 attack drone is, so realism and the mechanism
agree.

**The defender pays too.** Defending drones leave the roster on the same terms.
An island that is popular gets ground down by attention, which is a real cost
and is not compensated with a made-up reward. What the defender gets is in the
next section, and it is worth more than airframes.

**And there is a second price, which is the home advantage given up.** An
island's static sensor network defends its own airspace only, so a raiding swarm
flies into somebody else's volume with no ground support at all. Choosing to
attack means choosing to fight without the thing that makes you strong. The full
design is in [DESIGN_THE_STATIC_DEFENCE.md](DESIGN_THE_STATIC_DEFENCE.md).

⚠ **Which is also the design's most likely failure mode.** If home advantage is
overwhelming, every island turtles, no genomes cross, and the charter's one idea
dies while the exhibit still looks busy. The viability criterion is fixed in
advance: **a competent attacking swarm must win a non-trivial fraction of raids
against a competent defence**, and network strength is set on that with the whole
sweep published.

## What the defender gets, and it is the best part

**The attacker's genomes.**

A raid delivers, to the defender, N controllers bred by a population it has
never seen, under selection pressures it did not choose. Those enter its
**opponent set** permanently, and its own trainer then has to beat them.

That is the mechanism by which the archipelago is more than four separate
experiments, and it is a use of coevolution that 057's refusal does not touch,
because what crosses is diversity rather than a coupled opponent.

⚠ **And it means to raid is to publish your swarm.** Permanently, to whoever you
attacked. An island that raids constantly hands its lineage to everyone it
touches; an island that never raids never gains a foreign opponent and evolves
in a mirror. There is no free answer to that, which is what makes it worth
watching. It is disclosed in `README.md` for the same reason the sibling
rumbler disclosed genome republication: a sender cannot infer it from *send a
swarm, get a result*.

## What a veteran carries: the Lamarckian fork

With `evaluate_with_plasticity/3` enabled, weights change during an engagement.
So when a survivor comes home there are two different things it could carry, and
this is a real fork rather than a detail.

| arm | what is stored | what it is |
|---|---|---|
| **W** | the weights it took off with | Weismannian. The raid is a second, harsher exam: surviving is **evidence about** a genome, not a change to it |
| **L** | the weights it came home with | **Lamarckian inheritance**. What the drone learned in the fight is heritable |

⚠ **CORRECTED 2026-08-05: arm L is not built, because this engine cannot do it.**
`evaluate_with_plasticity/3` does not exist. faber ships `plasticity.erl`, but it
operates on genotype-shaped `{Weight, Delta, LearningRate, Params}` tuples rather
than on the flat quantized vector this genome is, and the genotype path is the
one the faber boundary test deliberately forbids. Arm L would mean per-synapse
learning rates entering the genome — changing its width, every persisted genome
and the engine fingerprint — plus per-tick activation capture. That is a build,
not a dial. **Arm W is the only arm, and it is described as such rather than as a
choice.** See REGISTER D.11.

~~Both are built, arm L is the default, and the choice is a runtime dial.~~
Lamarckian evolution is a real and well studied family that often outperforms
its alternative in practice, and it is what the track was described as wanting.
Making it a dial rather than an assumption means the question *is the learning
doing anything, or is it the selection* has an answer that costs one run.

**Separately, and orthogonally: veteran status biases parent selection.** A
genome with a `veteran_of` entry is more likely to be chosen as a parent. That
is a second dial, and it is the Weismannian way to get the same intuition: a
genome that survived a real defender is better evidence than one that only ever
beat the drills.

⚠ Two dials, turned independently, because with both on and no ability to
separate them nobody could say which was responsible.

## The trainer

Steady state, not generational, because the island has to keep publishing and
keep answering raids while it searches.

```
pick parents from the roster, biased by fitness and by veteran status
vary:  mutate weights, and cross two parents
evaluate: a sample of the opponent set over a sample of the start geometries
admit if it beats the worst entry; evict the worst
```

Variation is a plain vector operator over `network_evaluator:get_weights/1` and
`set_weights/2`, with self-adapting step size. That seam is exactly why the
library is a dependency; see
[DESIGN_WHAT_WE_TAKE_FROM_FABER.md](DESIGN_WHAT_WE_TAKE_FROM_FABER.md).

The evaluation runs on the **NIF path**, where throughput matters and exactness
does not.

⚠ **The opponent sample is drawn, never taken whole.** Evaluating against every
captured genome would make training cost grow without bound as an island is
attacked more, and would make a popular island slower at exactly the moment it
most needs to improve.

## The frozen benchmark, which is the only improvement number

**A fixed set of scripted drills over a fixed set of start geometries, never
trained against, run on a timer, published.**

Insight 054 is the reason and it is not subtle: a benchmark that is not fixed
and graded goes silently blind, and a population evolving against a widening
opponent set will show a rising local fitness that measures the exam rather than
the population. Every foreign genome captured changes the training exam. Without
a frozen one there is no honest sentence to write about whether anything got
better.

⚠ **It is an away game, always: no sensors, no cueing, ground bank forced to
zero.** This is the same failure a second time and it would have been easy to
miss. If the benchmark ran at home, an island that improved its **fortifications**
would show a rising benchmark score, and that score would not be about its drones
at all. It would be a number reporting progress while measuring something other
than the thing it names. The defence network gets its own separate published
number and the two are never added together.

**Graded, not pass/fail.** 054's specific finding is that a benchmark too weak
to stretch the population saturates and then reports nothing, having been blind
to roughly 31 of about 35 units of progress. So the drills span a ladder from
trivial to hard, and the score is a profile rather than a single number.

Candidate drills, each a behaviour rather than a tactic: a **hoverer** that does
nothing, a **climber**, an **orbiter**, a **chaser** that greedily pursues, an
**evader** that greedily flees, and a **screener** that interposes. Six is a
starting guess; the ladder is fixed by measurement before the first breeding run
and never touched afterwards.

⚠ **Fixing it afterwards is forbidden.** A benchmark adjusted once training has
started measures the adjustment. If the ladder turns out to be wrong, a **new**
ladder is added beside the old one with its own name and its own history, and
the old one keeps being published.

## The behaviour archive

Every distinct tactic ever seen here, kept and counted, borrowed from
`novelty_strategy`'s archive and used **as an instrument and never as a
selector**.

The count of distinct behaviours ever seen is the operational measure of whether
an island is still discovering or has converged, which is the closest thing this
substrate has to a reading of open-endedness. It requires no change to selection
and the descriptor is already computed for the benchmark profile.

## Raid initiation

An island decides for itself when to raid and whom. The policy is deliberately
simple to start, because a clever policy would be a tactic nobody evolved:

```
every RAID_INTERVAL, if the roster is above a floor,
pick a target from the islands heard from recently, and send N.
```

The floor stops an island raiding itself to extinction, which is a real risk
once genomes are spent by flying and is the local version of what killed every
configuration in insight 062.

⚠ **A target is chosen from islands this one has heard publish**, so an island
that is silent is not attacked. That is not a protection, it is a consequence:
there is no directory, and the public realm is the only place islands become
visible to each other.
