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
TICK      50 ms, so 20 a second
position  1 metre    = 20480 units      resolution ~0.049 mm
velocity  1 m/s      = 1024 units PER TICK
```

⚠ **The position scale follows from the velocity scale rather than the other way
round.** 20480 is 1024 times 20, chosen so that one metre per second is a whole
number of units per tick and integration is `Pos + Vel` with **no division**. A
divide-per-tick would truncate every position slightly toward zero and the world
would acquire a drag nobody wrote. Hovering holds altitude to the unit because of
this, and there is a test that says so.

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
**clamped and takes damage proportional to the speed the surface absorbed**, so
the boundary is a hazard rather than a resource. Register `D.1`: a drone at full
throttle from the middle of the arena reaches the far wall at about tick 286 and
grinds itself to death against it by tick 300.

The four LATERAL walls are also the way out, under conditions that cannot be met
by crashing. See "Leaving alive" below.

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
vx, vy, vz         fixed-point, units per tick
yaw                binary angle, 0..255, 256 = full turn
battery            centijoules remaining
health             out of 10000
release_heat       ticks until the unguided weapon is ready
launch_heat        ticks until the guided weapon is ready
magazine           interceptors remaining
dead               boolean
withdrawn          boolean, and NOT the same as dead
withdraw_hold      ticks spent loitering in the boundary margin
damage_taken       this tick only, and it conflates every source
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
draw per tick = T * isqrt(T) div 15        T is commanded thrust magnitude
```

⚠ **Power goes as thrust to the three halves**, which is momentum theory for a
rotor in hover, computed rather than approximated. Linear draw was considered and
rejected on the arithmetic: at a 5:1 ratio between full thrust and hover, linear
makes full throttle only five times as expensive, the battery never binds inside
a 60 second engagement, and the whole mechanism is decoration. As built, hovering
lasts about 9 minutes and full throttle about 46 seconds.

A drone at zero battery **stops producing thrust** and falls. It is not
teleported out and it is not declared dead; it becomes a falling object that can
still be hit and can still hit the ground. Running out is a way to lose rather
than a way to leave.

⚠ **The constants are chosen on viability and the whole sweep is published.**
Charter rule 3. The viability criterion is stated before the sweep runs: an
engagement between two competent swarms must usually end by damage rather than
by the turn cap, and must usually last longer than ten seconds. Any value that
fails either is out, whatever it does to any other number.

## Weapons: two, different in kind

⚠ **Revised 2026-08-05. This document said there was exactly one weapon,
"because two weapons is a balance problem and this repository has no means to
settle one". Both halves of that were wrong.**

The balance claim was weak: this repository has a frozen benchmark and a
viability discipline, so *which weapon does an evolved population actually reach
for* is a measurement rather than an argument.

The arithmetic was the real problem. At 60 m/s an unguided shot needs 1.7 s to
cross 100 m, and a target with 50 m/s^2 of acceleration displaces about **70 m**
in that time against a **2 m** hit radius:

| range | flight time | evasion | hit radius |
|---|---|---|---|
| 100 m | 1.7 s | ~70 m | 2 m |
| 50 m | 0.8 s | ~17 m | 2 m |
| 20 m | 0.33 s | ~2.8 m | 2 m |
| 10 m | 0.17 s | ~0.7 m | 2 m |

So one unguided weapon is effective inside roughly 15 m **and nowhere else**.
Every engagement would have been a knife fight, and "learned to engage at range"
would have been unreachable rather than merely unlearned, which is insight 059's
failure mode: the behaviour never appears because the budget went elsewhere, and
from outside that is indistinguishable from a population that declined.

**The release**, unguided, cheap, no magazine, effective at knife range. It
travels, expires and can miss, so firing is committing to a prediction, and
leading a manoeuvring target stays something this substrate can find rather than
something it was handed. That question survives precisely because this weapon
was kept.

**The interceptor**, guided, 80 m/s, a magazine of four, expensive in battery,
and it hits for twice as much so two of them kill.

⚠ **This paragraph used to claim the interceptor was beatable and it was wrong.
Measured 2026-08-05, registers `D.8` to `D.10`.**

It argued from turn RADIUS, 43 m against a drone's 25 m. A turning fight is
decided by angular rate, which is `a / v`: the missile turns at 1.875 rad/s
against a drone's 1.43, so it **out-turns the thing it is chasing**. It also had
no seeker field of view, so it never lost lock, and in a bounded arena a faster
pursuer that never loses track always reconnects.

Measured: **100% hit rate at every range from 30 m to 450 m**, against a target
running and against one breaking hard, and a sweep of the turn acceleration down
to a radius twenty-one times a drone's did not move it by one point.

The seeker now has a 120 degree field of view and loses lock for good, which is
a correctness fix and is kept. **The balance is not fixed.** The sweep found the
criterion can be met below about 0.26 rad/s and that meeting it makes the game
unplayable: a bred population ran 160 rounds at that setting and never left the
floor of the frozen ladder. Speed was swept too and makes it worse, because at
close range a break turn is decided by time of flight rather than by agility.

**So `D.6` stands open as a design question rather than a tuning one**, the
constant is the original, and the claim below is what the design WANTS rather
than what it currently delivers: the release rewards closing, the interceptor
rewards seeing first.

**A launch needs a lock** and spends nothing without one: the nearest hostile
inside a 45 degree seeker cone and 600 m. The cone is tested by dot product
against the nose, never by an angle, so there is no `atan2` on the match path.
Nothing tells the controller it has a lock; bearing, range and affiliation are
already in its contact channels, so that is something to learn.

Guidance is **pure pursuit at constant speed with a lateral acceleration limit**,
which is what a cheap seeker does. A lost target leaves the interceptor
ballistic rather than deleting it, because a munition that vanished when its
target left would let a swarm clear the sky by withdrawing one drone.

Collisions between drones cause damage to both. Ramming is not designed, it is
what falls out of two solid objects in one volume, and a swarm that discovers it
has discovered something.

Collisions between drones cause damage to both. Ramming is not designed, it is
what falls out of two solid objects in one volume, and a swarm that discovers it
has discovered something.

## Leaving alive

⚠ **Added 2026-08-05, and the argument for it is the strongest one available.**

Insight 062 closed programme P7 on a squeeze: *the only restraint available is
decline-to-hunt, which is eat nothing, so restraint is inseparable from
starvation, and no costless restraint lever exists.* An arena that is a closed
box with hostile walls rebuilds that exactly. A drone that decides it is losing
has nowhere to go, so fleeing is a slower way of dying, and "retreat" is
unrepresentable rather than merely unchosen.

**So the four lateral walls are an exit.** A drone that holds station inside a
10 m margin, below 5 m/s, for two seconds is **withdrawn**: alive, out of the
engagement, and its genome goes back on the roster.

The sensors for the decision already exist and no new one is added: battery
remaining, health remaining and damage taken this tick are all in the
proprioception block. ⚠ There is no `withdraw` actuator either. Charter rule 8:
no channel may name a tactic, and retreat is flying somewhere at a speed, which
the existing controls already express.

⚠ **It is a HOLD rather than an instant, and register `D.3` is why.** The first
version gated on speed at the moment of crossing, and a wall impact is clamped,
which sets the speed to zero. So flying into the boundary at 17 m/s qualified as
a controlled departure on the very next tick, and crashing was the cheapest way
out. The clamp now happens first and the exit is checked after, so a wall is
never a way through a wall.

⚠⚠ **And it is the design's next most likely failure mode.** If leaving is too
cheap, the dominant strategy is take off, leave, survive, and the exhibit becomes
nothing happening. The criterion is fixed in advance and it is set at the raid
level rather than here: **a raid that withdraws without achieving anything must
be worth less than one that wins.** The ground and the ceiling are deliberately
not exits: landing gently in somebody else's airspace is not withdrawing from it.

**Who held the airspace and which genomes came home are now two questions.** A
side can withdraw intact and lose the engagement, which is the trade the
mechanism exists to offer. `winner/1` answers the first, `survivors/1` the
second.

## Reproducibility, and where it stops

**Everything in the arena is integer.** Fixed-point positions, binary angles, a
checked-in sine table, no `math:` call anywhere on the arena path. There is no
wall clock in the loop and no `rand` outside the seeded generator, and
`airspace_determinism_tests` asserts that structurally over the compiled call
graph rather than trusting this paragraph.

⚠ **THE BRAIN IS NOT, AND THAT IS A DECISION RATHER THAN AN OVERSIGHT. Decided
2026-08-05, and this section previously claimed the opposite.**

It claimed a table-based activation would make the whole path bit-identical, on
the grounds that `network_evaluator` takes an `activation` atom and dispatches
through `functions`. That is false. `apply_activation/2` is **private**, its
clause list is closed, and its last clause reads:

```erlang
apply_activation(X, _) ->
    math:tanh(X).
```

So an unrecognised activation atom does not fail: it **silently becomes libm
tanh**. There is nothing to register.

The choice made was to keep `faber_tweann`'s evaluator as it is, with CfC memory,
in-episode plasticity and the Rust NIF, and to give up bit-identical replay across
runtimes. What that costs and what it does not:

| | |
|---|---|
| same image, same OTP, same libc | **exact.** The fleet runs one image, so replay works today |
| different libc or OTP release | **approximate.** libm `tanh` may differ in the last place, and a fight can diverge at a decision boundary |
| the arena's contribution to divergence | **none.** It is integer, and that is why the integer work is still worth having |

⚠ **The value of keeping the arena exact goes up rather than down.** Divergence is
now localised to one function in one module and bounded at about one unit in the
last place, instead of being spread across every position, every velocity and
every collision test. A known, small, single-source discrepancy can be measured;
a diffuse one cannot.

⚠⚠ **So a defender's published raid is reported, not proved.** An attacker can
replay it and expect agreement on a matching runtime, and cannot demand it
otherwise. The engine fingerprint that travels with a raid request must therefore
name the **OTP release and the libc** as well as the code, because those are now
part of what determines the fight. That is
[DESIGN_WHAT_CROSSES_THE_MESH.md](DESIGN_WHAT_CROSSES_THE_MESH.md)'s business and
it is owed at item 7.

## What is published from a fight

The result, always. The frames, always, because a fight is worth watching and a
ticker is not. Both are in
[DESIGN_WHAT_CROSSES_THE_MESH.md](DESIGN_WHAT_CROSSES_THE_MESH.md).

A frame is emitted every **second** tick, so 10 Hz of drawing from 20 Hz of
simulation. Nothing in the physics reads that number; it is a publishing
decision and it lives with the publisher.
