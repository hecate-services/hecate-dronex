# The second act

**This exists so the counter-UAS line is disposed of honestly: most of it comes
into act one as an island's static defence, the rest is named as deferred, and
nothing is deleted quietly.**

⚠ **Revised 2026-08-05, the same day it was written.** The first version deferred
the whole line as a future division. That was wrong, and the design document it
produced is now
[DESIGN_THE_STATIC_DEFENCE.md](DESIGN_THE_STATIC_DEFENCE.md). The reasoning for
the reversal is charter rule 4, restated: **a capacity that was never exercised
is not evidence of anything.** A kept contract nobody publishes on is a guess
about a future negotiation, and kept code that nothing runs rots.

---

## What came forward into act one

The detection layer **is** an island's static defence network. It is not a
future division and it is not a mode: it is what makes attacking harder than
defending, what gives an attacker something to solve that is not another drone,
and what makes two islands visibly different places.

| came forward | as what |
|---|---|
| the `dronex_sensor_model` behaviour | the definition of a sensor. Ground truth in, this sensor's report or a miss out. **The best thing this line produced** |
| the `airspace.contact_observed` field set | what a sensor reports, inside the engagement loop |
| the `airspace.track_confirmed` shape | what the fusion produces and what cueing transmits about |
| the architectural separation | sensors produce contacts, something else makes tracks, the consumer never learns which sensor produced what |
| the swap-point discipline | now at perception and actuation as well as at detection |
| `remote_id_sensor_model`'s structure | as the **second** modality, for tracking friendly drones, since an attacker does not broadcast |

The full design, including what does **not** port and why, is in
[DESIGN_THE_STATIC_DEFENCE.md](DESIGN_THE_STATIC_DEFENCE.md).

## What is retired, and why

The retirements are unchanged. They were never about the subject; they were
about the machinery.

| retired | why |
|---|---|
| `simulate_airspace`'s event-sourced drone aggregate, and the `enter_airspace`, `reposition_drone`, `depart_airspace` slices | **one reckon-db write per drone per reposition.** An island runs thousands of engagements an hour at 20 Hz with sixteen drones. Not merely unused, wrong by three orders of magnitude. Contacts and tracks inside a fight are terms in a fold |
| `air_track_aggregate`, `confirm_track`, `maybe_confirm_track` | the CQRS wrapper around a track. Same reason, and the logic inside it is a one-shot idempotence guard rather than an evidence accumulator |
| `on_contact_observed_correlate_track` | its own docstring calls it "the SKELETON minimum", and `TrackId = <<"track-", DroneId/binary>>` shows why: it keys on the drone's **self-reported identity**, which exists only for Remote-ID. There is no association, no gating and no track-lost. The track algorithm is written rather than ported |
| the two-release `dronex_edge` / `dronex_sim` split | there is one release now: an island. The wall separated a production site brain from a simulator, and an island is both |
| `query_detection_quality` as a service | the **idea** survives as an instrument, restated as *what a drone perceived* against *what was there*, which is what catches a controller exploiting a simulator artifact. The evoq projection and its store do not |

Everything retired stays in git history, and this document is the pointer.

## What is still genuinely deferred

Three things, and they are the parts that were about a **product** rather than
about a world.

**Federated multi-site fusion.** Many sites, each with sensors, pooling tracks
across the mesh. An island is one site. The contract survives, so this remains
buildable; nothing here needs it.

**Operator alerting.** A console, a human in the loop, thresholds somebody has
to tune. There is no operator inside an engagement.

**Real hardware ingest.** RF demodulation, an actual Remote-ID receiver,
acoustic classification, vision inference. This is the far side of the swap
point, and the behaviour is what makes it reachable.

## The swap point, restated

The old architecture turns on one idea and it survives intact:

> one contract, produced identically by a simulated sensor and a real one, so
> the simulator can be swapped for hardware and nothing downstream changes.

It now sits on **two** seams rather than one, and the second is new:

| seam | swap what | what must not change |
|---|---|---|
| **detection** (inherited) | a simulated ground sensor for a characterised real one | the fusion that consumes contacts |
| **perception and actuation** (new) | a simulated onboard sensor for a real one, and eventually the simulator for an airframe | the controller, which is why every drone sensor channel is a quantity a real airframe can produce |

That second row is why [DESIGN_THE_DRONE.md](DESIGN_THE_DRONE.md) refuses any
channel a simulator can compute and an airframe cannot, and it is what makes the
ONNX export a meaningful test rather than a demonstration.

## What the framing costs, said plainly

The old `README.md` stated that nothing in the repository jams, hijacks or
engages aircraft. **That sentence is gone, because engaging is the subject.**

What replaces it is a boundary drawn in the architecture rather than only in
prose, the same way `dronex_edge` contained zero simulation code:

- no ingest of live airspace data, no Remote-ID decode from a real radio, no
  telemetry path in
- no interface that accepts a real sensor feed
- the only things that cross the mesh are a genome, a result and a recording

⚠ The ONNX export is a deliberate exception to *closed*, and it is the point of
the track rather than a leak: a controller is meant to be able to leave. That is
the charter's first line, and it is what *a virtual environment for potentially
real-world drone AI* commits to.
