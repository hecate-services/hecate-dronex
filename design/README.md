# Design

**One document per topic, each carrying its decision, the reasoning that
produced it, and what it rejected.**

`CHARTER.md` in the root is the front door: the end goal, the classification,
the rules, the instruments, the vocabulary and the order of work. It states what
this track is committed to. **These documents say why**, and they are where a
commitment gets relitigated if new information arrives.

## The documents

| document | what it decides |
|---|---|
| [DESIGN_THE_AIRSPACE.md](DESIGN_THE_AIRSPACE.md) | continuous fixed-point 3D rather than a lattice, the flight model, the battery, hits, and what makes a fight reproducible |
| [DESIGN_THE_DRONE.md](DESIGN_THE_DRONE.md) | the body, the sensor channels, the actuator channels, the brain, the genome on the wire, and the perception boundary |
| [DESIGN_DRONES_THAT_TALK.md](DESIGN_DRONES_THAT_TALK.md) | an uninterpreted channel, range and latency, permutation-invariant aggregation, interception, and the ablation that makes coordination measurable |
| [DESIGN_THE_ROSTER_AND_THE_RAID.md](DESIGN_THE_ROSTER_AND_THE_RAID.md) | the lineage loop: a finite roster, local training against a widening opponent set, the frozen benchmark, what a raid costs and what it returns |
| [DESIGN_WHAT_CROSSES_THE_MESH.md](DESIGN_WHAT_CROSSES_THE_MESH.md) | topics, realms, the raid request and reply, the frame budget, and the wire rules each of which was earned by something that broke |
| [DESIGN_THE_MAP.md](DESIGN_THE_MAP.md) | the archipelago, the airspace volume, raid arcs, drawn signals, the replay player, and the bug that has to be fixed first |
| [DESIGN_WHAT_WE_TAKE_FROM_FABER.md](DESIGN_WHAT_WE_TAKE_FROM_FABER.md) | the dependency boundary, module by module, with the float determinism split and a record of the survey error that produced it |
| [DESIGN_THE_SECOND_ACT.md](DESIGN_THE_SECOND_ACT.md) | what the counter-UAS line leaves behind, what is retired, and where the swap point moved |

## What goes here, and what does not

**Here:** a decision that shapes the model, with its reasoning. An exploration
that has not become a decision yet, named `EXPLORATION_*.md`. Measurement that
informs several decisions, named `RESEARCH_*.md`.

**Not here:** a claim about the world, which is a pre-registration and lives in
`claims/`. A finding or a mistake, which is an entry in `REGISTER.md`. How the
service is built, run or deployed, which is `README.md`. The retained
counter-UAS design record, which stays in `architecture/`.
