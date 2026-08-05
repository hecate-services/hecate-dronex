# The second act

**This exists so the counter-UAS line is retired honestly: what it leaves
behind is named and kept, what is retired is named and why, and nothing is
deleted quietly.**

---

## Why it is a second act rather than a dead branch

The repository opened as **federated counter-UAS airspace awareness**: many
cheap heterogeneous sensors, fused over the mesh into one track, scoped strictly
to `detect -> classify -> track -> alert`. Eight applications, two releases with
a hard wall between them, event-sourced aggregates, over-mesh tests, two design
documents and their PDFs.

That is real work and it answers a real question. It is also the **obvious next
question** for this track: if islands evolve attack swarms, the thing you
naturally want next is evolved **defence**, and defence is detection, tracking
and intercept.

So it is not deleted. Charter rule 9.

## What is kept, and why each one earns it

| kept | why |
|---|---|
| `apps/shared/dronex_contracts` and the fact names `airspace.contact_observed`, `airspace.track_confirmed` | the contract a defence side publishes on. Cheap to keep, expensive to reinvent, and naming them now means a later defence slots in rather than negotiating |
| the `dronex_sensor_model` **behaviour** | a sensor as a module with a declared degradation from ground truth to observation. **The single most reusable idea in the old repository**, and it is exactly the shape a drone's onboard sensing needs. It is also how a characterised real sensor is ever dropped in |
| the scoring-oracle idea from `query_detection_quality` | ground truth against estimate. Restated at the new seam it becomes *what a drone perceived* against *what was there*, which is the instrument that catches an evolved controller exploiting a simulator artifact rather than learning a tactic |
| `architecture/DESIGN_DRONEX_MESH.md`, `architecture/DESIGN_DRONEX_SIMULATION.md` and their PDFs | the design record, with a note at the top saying which seam they describe |

## What is retired, and why

| retired | why |
|---|---|
| `apps/edge/fuse_airspace`, `air_track_aggregate`, the `confirm_track` slice, the `on_contact_observed_correlate_track` process manager | answers *can many cheap ground sensors be fused into one track*. A real question, a different question, and nothing on the path to swarm combat |
| `apps/sim/simulate_airspace`'s event-sourced drone aggregate, `enter_airspace`, `reposition_drone`, `depart_airspace` | **one reckon-db write per drone per reposition.** An island runs thousands of engagements an hour at 20 Hz with sixteen drones. This is not merely unused, it is the wrong shape by three orders of magnitude, and the combat engine must be an in-memory integer fold |
| `apps/sim/observe_remote_id` | a ground receiver decoding Remote-ID broadcasts. Belongs to the defence act |
| the two-release `dronex_edge` / `dronex_sim` split | there is one release now: an island. The wall it enforced was between a production site brain and a simulator, and both sides of that wall belong to the second act |

Everything retired stays in git history, and this document is the pointer.

## The swap point moved, and that is the substantive change

The old architecture turns on one idea, and it is a good one:

> one fact contract, produced identically by a simulated sensor and a real one,
> so you can swap the simulator for hardware and nothing downstream changes.

**The idea survives. The seam moves.**

| | old seam | new seam |
|---|---|---|
| where | **detection**: a ground sensor node publishes `airspace.contact_observed` | **perception and actuation**: what a drone's own controller sees, and what it commands |
| swap what | a simulated Remote-ID receiver for a real one | a simulated onboard sensor for a characterised real one, and the simulator for an airframe |
| what must not change | the fusion pipeline downstream | the controller, which is why the sensor channels are all quantities a real airframe can produce |

That last row is why [DESIGN_THE_DRONE.md](DESIGN_THE_DRONE.md) refuses any
channel a simulator can compute and an airframe cannot. It is the old
architecture's discipline applied at the new seam, and it is what makes the ONNX
export in order-of-work item 9 a meaningful test rather than a demonstration.

## What the framing costs, said plainly

The old `README.md` states that nothing in the repository jams, hijacks or
engages aircraft. **That sentence goes, because engaging is now the subject.**

What replaces it is not silence. The repository is a **closed simulation** and an
evolutionary substrate, and the boundary is drawn in the architecture rather than
only in prose, the same way `dronex_edge` contained zero simulation code:

- no ingest of live airspace data, no Remote-ID decode, no telemetry path in
- no interface that accepts a real sensor feed
- the only thing that crosses the mesh is a genome, a result and a recording

⚠ The ONNX export is a deliberate exception to *closed*, and it is the point of
the track rather than a leak: a controller is meant to be able to leave. That is
stated in the charter's first line and it is what the framing *a virtual
environment for potentially real-world drone AI* commits to.

## If the defence act is ever built

It is a **division of its own**, not a mode of this one. An island evolves
attackers; a defence node fuses sensors and intercepts. They meet at
`airspace.contact_observed`, which is why the contract is kept.

Whether it lives here or in a repository of its own is a decision for whoever
starts it, and it is not made in advance. What this document guarantees is that
the seam and the contract will still be here when it is.
