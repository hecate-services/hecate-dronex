# hecate-dronex

**Federated counter-UAS airspace awareness as a realm-bound mesh service.**

`hecate-dronex` turns a fleet of cheap, heterogeneous drone-detection
sensors into one coherent airspace picture, over the
[Macula](https://codeberg.org/macula-io) mesh, with no cloud and no single
point of failure.

It is the **nervous system**, not the senses. The mesh handles discovery,
routing, sensor fusion and alerting across the fleet. The actual detection
(RF demodulation, Remote-ID decode, acoustic classification, vision
inference) is application logic that runs at each sensor node and publishes
**detection facts** to the mesh.

> Scope is strictly **detect → classify → track → alert**. This is
> defensive airspace situational awareness for perimeter security and
> critical-infrastructure protection. Nothing in this repo jams, hijacks,
> or engages aircraft.

## Layer position

```
Layer 4 - apps        hecate-app-dronex   (operator console + thin plugin
                                            shim in hecate-daemon)
Layer 3 - session     hecate-daemon
Layer 2 - services    ▶ hecate-dronex ◀   (this repo)
                                            fusion + alerting on edge cluster
Layer 1 - identity    hecate-realm
Layer 0 - kernel      macula-station
```

## Why a mesh

Drone detection is a **distributed sensor-fusion** problem. No single
sensor is reliable alone; you need many cheap nodes fused into one track.
That is exactly what a capability mesh is for:

- **Federated, no cloud:** survives degraded or contested comms; keeps
  fusing locally when the uplink is cut.
- **Edge-native:** a sensor node is just a Hecate daemon advertising a
  detection capability.
- **Sovereign data path:** no Big Tech in the chain; a hard requirement
  for European critical-infrastructure and public-sector procurement.
- **Edge AI that fits:** detection is compact, per-modality classifiers
  running inside each sensor slice (not a language model). Candidate path to
  producing and improving them is federated neuroevolution
  (`macula-tweann` / `macula-neuroevolution`) across the fleet, with raw
  sensor data never leaving the site.

## Documentation

| Document | Purpose |
|----------|---------|
| [architecture/DESIGN_DRONEX_MESH.md](architecture/DESIGN_DRONEX_MESH.md) | Working design document: modalities, primitive mapping, DDD shape, gaps, strategy |
| [architecture/DESIGN_DRONEX_MESH.pdf](architecture/DESIGN_DRONEX_MESH.pdf) | Same, as a distributable PDF (cover + diagrams) |

Build the PDF:

```bash
scripts/build-pdf.sh
```

## Status

Architecture / concept stage. Working document and diagrams first; walking
skeleton (`detect_remote_id` division + `contact_observed` fact schema +
fusion process manager) to follow.

## License

Apache-2.0. See [LICENSE](LICENSE).
