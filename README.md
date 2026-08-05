# hecate-dronex

**A virtual environment for potentially real-world drone AI.**

One machine runs one **island**. An island breeds a population of autonomous
drone controllers, keeps them, sends some of them to attack another island, and
hosts the fights it is attacked in. The controllers are neural networks, and
nothing about how they fly, coordinate or fight is written down anywhere. A
champion can be exported to ONNX and flown outside the simulator.

> **This exists so a swarm bred on one machine can attack a swarm bred on
> another, and so the controller that wins can leave the simulator and fly.**

Read [`CHARTER.md`](CHARTER.md) first. It states what this track is committed to,
and the one claim it is not allowed to make. [`design/`](design/) says why, one
document per topic.

## Where the interesting part is

Every island runs the same physics and differs only in what it has bred and what
has attacked it. Three things are given: the airframe, the sensor channels, and
that raids happen. Everything else is found.

- **Drones talk, and nothing declares what a signal means.** Four channels out,
  four in, range-limited, one tick late, summed over everyone in earshot. The
  enemy hears it too, so signalling trades coordination against disclosure.
  Whether it is used at all is measured by replaying the same fight with the
  channel muted.
- **A genome is spent when it flies.** Losing a raid costs airframes, and
  rebuilding costs breeding time. The roster is finite and contested.
- **A raid is how diversity crosses the mesh, not how fitness is assigned.** The
  defender keeps the genomes that attacked it and trains against them
  afterwards. Selection stays local, against an opponent set that raids widen.
- **You fight at home with your sensor network, and away without it.** An island
  has ground sensors with real coverage and real blind corridors. They cue the
  defending swarm by **transmitting**, on the same uninterpreted channel the
  drones use, so a defender has to learn what a cue means and an attacker can
  learn to hear that it has been seen.

⚠ **To raid is to publish your swarm.** A raid hands your controllers to whoever
you attacked, permanently and by design, because that is the mechanism the whole
archipelago runs on. An island that raids constantly gives its lineage away, and
one that never raids never gains a foreign opponent. This is disclosed here
because you cannot infer it from *send a swarm, get a result*.

## What it is not

A closed simulation and an evolutionary substrate. It ingests no live airspace
data, decodes no Remote-ID, and has no interface that accepts a real sensor feed.
The only things that cross the mesh are a genome, a result and a recording.

The repository previously held a counter-UAS airspace-fusion line. Its detection
layer is not deleted and not deferred: it **is** the static defence network
above, described in
[design/DESIGN_THE_STATIC_DEFENCE.md](design/DESIGN_THE_STATIC_DEFENCE.md). What
of that line is retired, and what stays deferred, is in
[design/DESIGN_THE_SECOND_ACT.md](design/DESIGN_THE_SECOND_ACT.md).

## Layer position

```
Layer 4 - apps        (none yet)
Layer 3 - session     hecate-daemon
Layer 2 - services    > hecate-dronex <   this repo, one island per node
Layer 1 - identity    hecate-realm
Layer 0 - kernel      macula-station
```

An island is a `hecate_om` service: one OTP release, one container, a
`gen_server` holding the island, a reckon-db store holding the roster, and facts
published to a public realm.

## Watching it

Islands publish to `net.beamcampus.dronex`, whose realm id is the sha256 of that
name and therefore needs no provisioning:

```
686fbbf84c5c33455764f4c07c642bd1b79ef4efc78455f61ac12936ca3bffe3
```

The site subscribes and draws. It holds no engine and runs no physics: a raid is
published as a recording and played back locally.

## Documentation

| Document | Purpose |
|----------|---------|
| [CHARTER.md](CHARTER.md) | the front door: end goal, classification, rules, instruments, order of work |
| [design/](design/) | one document per topic, each with its decision and its reasoning |
| [REGISTER.md](REGISTER.md) | findings and mistakes, written down once so they are not paid for twice |
| [architecture/](architecture/) | the retained counter-UAS design record. See `DESIGN_THE_SECOND_ACT.md` |

Build the retained architecture PDFs:

```bash
scripts/build-pdf.sh                        # every architecture/DESIGN_*.md
scripts/build-pdf.sh DESIGN_DRONEX_SIMULATION.md
```

## Build

```bash
rebar3 compile
rebar3 eunit
rebar3 lint
rebar3 dialyzer
```

Rust is required for the native builds, which is already true of any macula
consumer: the QUIC and crypto NIFs are the price of joining the mesh at all.

## Configuration

⚠ **A node config may name what a node IS. It may never name what the physics
ARE.** Charter rule 2. The physics ship with the image or they are not physics.
A sibling put two of three fleet nodes into a two-hour boot-crash loop by keeping
a world constant in a deployment repository on a different release cadence.

| variable | what it names |
|----------|---------------|
| `HECATE_REALM` | the fleet realm, for identity and for inbound raid requests |
| `HECATE_DRONEX_REALM` | the public realm facts go out on. Defaults to the tag above |
| `HECATE_DRONEX_ISLAND` | this island's **nickname**. Two islands may share one |
| `HECATE_DRONEX_DATA_DIR` | the roster and the island's 128-bit identity |
| `MACULA_STATION_SEEDS` | which door this island reaches the mesh through |
| `HECATE_DRONEX_SEED` | which run this island is |
| `HECATE_DRONEX_*_MS` | pacing |

⚠ **`HECATE_DRONEX_DATA_DIR` must be a bind mount on a bulk drive.** Without it
an island does not merely lose its roster: it mints a **new identity** at every
restart, and every fact it has ever published is orphaned from the thing that
published it. The beam nodes boot from a 29 GB eMMC with a 13 GB root, so
application data belongs on `/bulk0`.

## Status

Design written 2026-08-05. Building starts at order-of-work item 1 in
[`CHARTER.md`](CHARTER.md): the `hecate_om` spine, release, container and CI,
before anything interesting, so that no later increment waits on plumbing.

## Credit

The design owes four things to the `robo_*` line in `rgfaber/faber-tweann`, none
of which is used as code and all of which is used as judgement: a perception
boundary enforced by destructuring rather than by comment, a canonical wire
format over tuples and integer lists, validating a stranger's genome rather than
clamping it, and treating the start set as a rule of the game rather than a test
fixture.

## License

Apache-2.0. See [LICENSE](LICENSE).
