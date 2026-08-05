# The map

**This exists so the archipelago is one world with fights visible on it, and so
the site that draws it never runs the physics.**

The map lives in `beam-campus/beam-campus-net`, not here. This document is the
contract: what an island publishes so that a map is drawable, and what the map
must not do.

---

## The standing rule, which was set by a correction

> **beam-campus.net SHOULD NOT REGENERATE. It should AGGREGATE and VISUALIZE.**

That was said after the sibling rumbler put the game engine inside the content
website: `apps/robo_rumbler` depended on `faber_tweann` and called
`robo_rumble:replay/2`, so the site became a second place the simulation ran and
had to stay version-locked to one node. `engine_id` on the wire and a turn-count
self-check were band-aids over a coupling that should not have existed, and every
spectator repeated about 1,900 frames of identical work.

**So dronex publishes frames.** The site plays a recording it was handed. It
holds no engine, computes no physics, and cannot draw a fight nobody fought.

## What had to be fixed before anything was built on it — DONE 2026-08-05

✅ **Fixed in `beam-campus-net` `45c0fb8`, deployed and live.** All four faults
below were real and the map had been blank since the camera landed. A test now
sweeps every colocated hook and asserts it defines the methods it calls, because
a hook that throws in `mounted()` fails silently: the page renders, the canvas
is in the DOM, nothing is drawn, and no compiler or assertion says a word. That
guard is verified to go red when `fitWorld`'s definition is removed again.

The record of what was wrong, kept because this track inherits the component:

Commit `64e1897` of 2026-08-04, *"The map is a viewport now: drag, zoom,
double-click to fit"*, added a camera to the `Archipelago` colocated hook in
`biotope_components.ex` and left it non-functional:

| | |
|---|---|
| `this.fitWorld()` | called three times, **never defined**. `mounted()` throws on the first call and the hook aborts |
| `this.at(px, py)` | called twice in the wheel handler, **never defined** |
| `fit()` | reads `dataset.width` and `dataset.height`; the canvas carries `data-world-width` and `data-world-height`, so both are `NaN` |
| `paint()` | never applies `this.cam`, so drag and zoom would move nothing even if they ran |

The biotope map was indeed blank on the live site, and had been since
`64e1897`. It was fixed first, because this track builds on the same component.

## The archipelago lifts unchanged

`Biotope.Archipelago` is 165 lines, pure, tested, and contains nothing about
biotope. It hashes an island's name into a cell on a fixed 16 by 16 grid, sorts
the names before placing so every viewer resolves collisions identically, then
squeezes the empty columns down to a sliver so that islands the hash threw far
apart are still drawn further apart than neighbours.

**A position is derived, never claimed.** No island announces coordinates, no
authority arbitrates, and any two viewers holding the same set of islands compute
the same map. The grid is fixed rather than sized to the population, which is
what makes a joining node **add land** instead of reshuffling everybody.

The camera model is right for the same reason: a world that grows without limit
stays readable only if the viewer moves, because the alternative is shrinking
every island as nodes join, so that adding land makes everything smaller.

## An island is a volume, not a disc

The sibling draws a hex disc because its world is a hex disc. This one draws
**airspace**, and it should not look like biotope with drones in it.

| element | how |
|---|---|
| the arena | a footprint on the sea, with a faint vertical extent |
| altitude | mark size plus a ground shadow, so height reads without a second view |
| **altitude bands** | faint horizontal rules, as real airspace has flight levels. A **reading aid only**: the physics is continuous and obeys nothing here |
| a drone | a mark, coloured by side, sized by altitude |
| a trail | a short fading tail, which is how velocity becomes visible on a still frame |
| the roster | a halo or bar per island, so an island ground down by attention visibly thins |
| **sensor coverage** | a soft footprint per static sensor, so **blind corridors are visible** |
| **a confirmed track** | the moment the defender knows, marked on the timeline |
| **the ground bank transmitting** | pulses from the ground, so *the network has seen them* is watched rather than read |

⚠ **Coverage is what finally makes two islands look different at a glance.**
Until now an island was a generic box with different genomes in it. With a
static defence network it has geography, and an attack either threads the gaps or
fails to. That is the single most watchable thing this exhibit can show and it
comes from [DESIGN_THE_STATIC_DEFENCE.md](DESIGN_THE_STATIC_DEFENCE.md).

⚠ **A raid away from home has no coverage to draw**, because an island's sensors
defend its own airspace only. So the same two islands look different depending on
which way the arc is pointing, and that is correct rather than a rendering bug.

## The arc is the thing this map has that no sibling map had

`Biotope.Archipelago`'s own moduledoc says the sea between islands holds nothing
and that **what would make the map say something true about connectedness is the
migration arcs**, which arrive with migration itself.

**A raid is that arc**, and here it is the subject rather than a promise.

- a raid in flight is drawn as an arc from attacker to defender
- with marks travelling along it, as many as the sortie
- returning with as many as survived
- so an island under attack is **visibly** under attack, and the direction of
  the archipelago's genetic traffic is a thing you can watch rather than a
  statistic

## Signals are drawable, and this is where coordination becomes visible

The comms channel is four integers per drone per tick, and the frames carry the
transmitted vector. So a swarm that is talking can be drawn as pulses between
marks, keyed to magnitude.

**A silent swarm and a coordinating one look different**, which is the single
most valuable thing this exhibit can show, and it costs four integers per drone
per frame.

⚠ **Drawing a signal is not measuring one.** The page may show pulses; it may not
say the swarm coordinated. That sentence needs the ablation delta from
[DESIGN_DRONES_THAT_TALK.md](DESIGN_DRONES_THAT_TALK.md), which is published as a
number and shown as a number.

## The replay player

A raid arrives as one fact with all its frames. The page:

- stores it, keyed by island
- plays it on a canvas with **scrub, pause and slow motion**, all local
- offers the ablation replay side by side when one has been published

None of that is possible against a live feed, and all of it is nearly free
against a recording.

## The technical discipline, inherited rather than rediscovered

The biotope page learned these expensively and they apply unchanged:

- **canvas, not DOM.** Marks are flat integer arrays in data attributes, and
  everything about how a mark looks is decided server-side where it is
  documented and tested. The hook interprets nothing.
- **coalesce redraws.** Every fact from any island used to redraw three discs of
  about 2,600 circles each, twelve charts and a table, six times a second, on a
  document that served at 711 KB. Nothing crashed: the socket could not keep up,
  dropped, and the client showed its reconnect banner. A LiveView that cannot
  ship its diff before the next one arrives is indistinguishable from a broken
  one. Redraw at most every 500 ms.
- **the announcement says which island spoke.** Without that, a page showing one
  island redraws for every other island's facts, and its moduledoc will claim
  otherwise while the code does the opposite.
- **untag at the edge.** CBOR encodes an atom and a binary identically, and the
  SDK decodes a text string to an existing atom **when one happens to exist**, so
  the shape a key arrives in depends on the receiving node's atom table. One
  published map has arrived with four atom keys and eleven string ones. Collapse
  both to strings once, at the edge, and never call `String.to_atom/1` on network
  input.
- **a dead island must not look alive.** The board keeps the last fact forever, so
  an island whose trainer stopped goes on showing its final frame. Show time
  since last heard from, per island.

## What the page must never do

- run the engine, or hold `faber_tweann`
- interpolate between frames, or fill a gap with a guess
- render a city from a station name
- show a merged island because two of them share a nickname
- claim coordination from a picture
