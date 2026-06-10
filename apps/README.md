# DroneX code layout

Two releases, one repo, a hard wall between them (see root `rebar.config`):

| Release | What | Apps |
|---------|------|------|
| `dronex_edge` | The site brain. Runs at a street/area/site. | `fuse_airspace` (+ `dronex_contracts`, root shell) |
| `dronex_sim`  | The driver. Simulates drones, weather, sensors; scores fusion. Includes the edge apps so a full loop runs on one node. | `simulate_airspace`, `observe_remote_id`, `query_detection_quality` (+ all of the above) |

`dronex_edge` contains **zero** simulation code. The production image
(`Containerfile`) builds only that release.

```
apps/
  shared/dronex_contracts/   the fact contracts + sensor-model behaviour (known to both sides)
  edge/fuse_airspace/        consume contact_observed -> confirm tracks -> publish track_confirmed
  sim/simulate_airspace/     ground-truth drone lifecycle + scenario driver + clock + weather
  sim/observe_remote_id/     Remote-ID sensor model + the emitter (ground truth -> contact_observed)
  sim/query_detection_quality/  the scoring oracle (ground truth vs track_confirmed)
src/                         root shell app: hecate_om boot, store wiring, HTTP, site/role
```

## The swap point, in code

The whole design turns on one fact contract, `airspace.contact_observed`,
produced identically by a simulated sensor and a real one:

```
simulate_airspace            (CMD, ground truth, local store)
  drone_repositioned_v1
      |
      v  evoq projection
observe_remote_id::on_drone_repositioned_observe_remote_id   <-- PRODUCER (sim)
  applies remote_id_sensor_model, publishes airspace.contact_observed to the mesh
      |
      |  ====== macula mesh ======   (a real Remote-ID receiver publishes the same fact here)
      v
fuse_airspace::on_contact_observed_correlate_track           <-- CONSUMER (edge)
  correlates -> confirm_track -> track_confirmed_v1 (local) + publishes airspace.track_confirmed
      |
      |  ====== macula mesh ======
      v
query_detection_quality::on_track_confirmed_record_estimate  <-- SCORER (sim)
  records the estimate; drone_repositioned_to_ground_truth records the truth;
  score_detection compares the two
```

Fusion (`fuse_airspace`) never names the simulator. Swap `observe_remote_id`
for a hardware sensor publishing the same fact and nothing downstream changes.

## Transport (mesh-only, like parksim)

Facts cross the macula mesh directly. Publishers inline the parksim pattern and
no-op while the node is dark:

```erlang
case {hecate_om:macula_client(), hecate_om_identity:realm()} of
    {{ok, Pool}, {ok, Realm}} -> catch macula:publish(Pool, Realm, Topic, Fact), ok;
    _ -> ok
end
```

Consequence: the full `dronex_sim` loop needs a reachable macula station +
realm to close (set `station_seeds` in `config/sys.config`). Ground-truth
events flow through the local store without one, and every slice is unit
testable on its own, but the contact/track fact hops are no-ops when dark.

## Build & run

```bash
rebar3 compile
rebar3 release -n dronex_edge     # production site brain
scripts/run-sim-local.sh          # build + run dronex_sim in a console
```

## Naming (per hecate-corpus codegen conventions)

CMD app = process verb (`simulate_airspace`, `fuse_airspace`); QRY = `query_*`;
command `{verb}_{noun}_v1`; event `{noun}_{past}_v1`; handler `maybe_{command}`;
aggregate `{noun}_aggregate`; process manager `on_{event}_{action}_{target}`
(sibling slice, own `_sup`). Status is integer bit flags via `evoq_bit_flags`.

## What is real vs next

This is a working walking skeleton, not a stub farm. Real and complete:
the ground-truth drone lifecycle, the Remote-ID sensor model (presence, range,
detection probability, GPS noise), the scenario driver with a scalable clock,
single-sensor correlation, and the scoring oracle.

Deliberately **absent** (next slices, not stubbed): other modalities
(`detect_rf`, `detect_acoustic`, `detect_optical`), multi-sensor triangulation
and track-lost handling in `fuse_airspace`, `alert_operators`, the L2 multi-site
topology, and L3 signal-level models. Add them as new slices; nothing here needs
to change to accept them.
