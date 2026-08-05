# The airspace

**This exists so the world a drone flies in is one a real drone could recognise,
and so two machines can agree on what a fight was.**

---

## It is not a lattice, and the reason is not aesthetic

The sibling worlds are hex grids, and hexagons are the right answer there for a
real reason: a hex tiling is the only regular tiling of the plane with **uniform
neighbour distance**, six neighbours all at distance one. A square grid has four
at one and four at root two, so movement cost depends on direction and
populations grow axis-aligned artifacts.

The 3D analogue exists and it is not the cube. A cube has six face neighbours at
1, twelve edge at root 2 and eight corner at root 3, which is worse anisotropy
than 2D squares. A hexagonal prism privileges the vertical axis, which is the
one axis a flight model must not privilege. The true analogue is the **rhombic
dodecahedron**, the cell of face-centred cubic close packing, with twelve
neighbours all equidistant.

**It is the correct answer to a question this world does not ask.** A creature in
the sibling worlds *steps* from cell to cell and the ground holds energy per
cell, so there the lattice is the physics. A drone does not step. It has
position, velocity, momentum and thrust, and it fights gravity continuously.
Discretising that would destroy momentum, make hovering and banking meaningless,
force a lattice-shaped sensor model unlike any real sensor, and quietly falsify
the charter's framing, because no drone moves in cell increments.

**So: continuous space in fixed-point integers.** Integers all the way down, as
coordinates in a volume rather than indices in a lattice.

⚠ **Hexagons are still welcome on the map**, where they are a rendering choice
with no physics in them. See [DESIGN_THE_MAP.md](DESIGN_THE_MAP.md).

## Units are real, because leaving the simulator is the point

Charter rule 7. Every quantity below is a real quantity in SI units, carried as
a fixed-point integer.

```
SCALE = 1024          1 metre  = 1024 units,  resolution ~1 mm
TICK  = 50 ms         20 Hz
```

20 Hz is chosen against two constraints and not for a result. Real flight
controllers run far faster, but tactics live at roughly the timescale of a
turn, and every doubling of the rate doubles the frames a raid has to publish.
20 Hz gives a 60 second engagement in 1200 ticks, which fits the frame budget in
[DESIGN_WHAT_CROSSES_THE_MESH.md](DESIGN_WHAT_CROSSES_THE_MESH.md) with room.

**The arena** is a box, because an unbounded volume lets a losing swarm simply
leave, which is neither a fight nor a result.

```
1000 m  x  1000 m  x  300 m ceiling,  ground at 0
```

A drone that reaches a wall does not bounce and is not teleported. It is
**clamped and takes wall damage**, exactly as the sibling engine did, so the
boundary is a hazard rather than a resource.

## The flight model, and what is deliberately not in it

**In:**

| quantity | why |
|---|---|
| position and velocity in three axes | the minimum for flight |
| thrust as a bounded acceleration in the **body frame** | a drone commands attitude and thrust, not world-frame velocity |
| yaw, and a bounded yaw rate | where the sensor cone points, which is most of what tactics is about |
| gravity, constant | makes altitude cost something |
| quadratic drag | gives a terminal velocity without a magic speed cap |
| **battery**, draining with thrust above hover | the real constraint on every airborne platform |

**Out, deliberately:** rigid-body six-degree-of-freedom dynamics, rotor mixing,
roll and pitch as evolved outputs, wind, and propeller aerodynamics.

⚠ **That exclusion is load-bearing and it is the lesson of insight 059.** There,
reactive fleeing was never learned under ecological survival fitness because the
evolutionary budget went elsewhere, and from outside that is indistinguishable
from a population that declined to flee. A controller made to learn attitude
stabilisation before it can learn anything else will spend its whole budget not
crashing, and the tactics this repository exists to find will never appear. The
airframe is assumed to have an inner loop, as every real one does. What evolves
is what sits **above** it.

State per drone is therefore:

```
x, y, z            fixed-point metres
vx, vy, vz         fixed-point metres per second
yaw                binary angle, 0..255, 256 = full turn
yaw_rate           signed
battery            fixed-point watt-seconds remaining
health             fixed-point
dead               boolean
```

Binary angles rather than radians because they wrap for free on an integer
addition and there is no rounding at the wrap point.

## The battery is a manoeuvre budget, not a loiter clock

Endurance is sized so that **hovering is cheap relative to an engagement and
hard flying is not**. A drone that hovers for the whole engagement lands with
most of its battery; a drone that flies at full thrust throughout runs out
before the cap. That makes energy a thing to spend tactically rather than a
countdown everyone experiences identically.

```
hover draw       a constant, paid every tick a drone is airborne
manoeuvre draw   proportional to commanded thrust above hover
```

A drone at zero battery **stops producing thrust** and falls. It is not
teleported out and it is not declared dead; it becomes a falling object that can
still be hit and can still hit the ground. Running out is a way to lose rather
than a way to leave.

⚠ **The constants are chosen on viability and the whole sweep is published.**
Charter rule 3. The viability criterion is stated before the sweep runs: an
engagement between two competent swarms must usually end by damage rather than
by the turn cap, and must usually last longer than ten seconds. Any value that
fails either is out, whatever it does to any other number.

## Weapons, and why there is exactly one

A drone can **release**, once its release is cool, along its current heading.
One weapon, because two weapons is a balance problem and this repository has no
means to settle one, and because the tactics under study are about position,
attention and coordination rather than loadout.

A release costs battery and produces a projectile that travels, expires and can
miss. It is not a hitscan. **A drone that fires is committing to a prediction**,
and predicting where a manoeuvring target will be is exactly the kind of thing a
recurrent controller can learn and a feedforward one cannot, which is one of
several reasons the brain has memory.

Collisions between drones cause damage to both. Ramming is not designed, it is
what falls out of two solid objects in one volume, and a swarm that discovers it
has discovered something.

## Reproducibility, and the one honest limit

**Everything in the arena is integer.** Fixed-point positions, binary angles, a
checked-in sine table, no `math:` call anywhere on the match path. A fight is a
pure function of the start state, the genomes and nothing else. There is no
wall clock in the loop and no `rand` outside the seeded generator.

⚠ **The brain is the exception, today.** The controller is a
`network_evaluator` network over floats, and its activation is `math:tanh/1`,
which is libm and is not guaranteed identical across libc versions. Float `+`,
`*` and `-` are exact under IEEE754 and BEAM uses SSE2 doubles with no extended
precision, so **the transcendental is the only source of divergence**, and a
table-based activation removes it entirely.

That gives a clean split rather than a compromise:

| path | used for | exact across machines |
|---|---|---|
| Rust NIF, `math:tanh` | **training**, where throughput matters | no, and it does not need to be |
| pure Erlang, table activation | **the published fight** | yes |

Until the table activation lands, replay agreement is a property of a fleet
running one image rather than a property of the design, and the charter records
that as owed.

## What is published from a fight

The result, always. The frames, always, because a fight is worth watching and a
ticker is not. Both are in
[DESIGN_WHAT_CROSSES_THE_MESH.md](DESIGN_WHAT_CROSSES_THE_MESH.md).

A frame is emitted every **second** tick, so 10 Hz of drawing from 20 Hz of
simulation. Nothing in the physics reads that number; it is a publishing
decision and it lives with the publisher.
