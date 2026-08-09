# The second weapon

**This exists so a drone has something to get good at that is not the
interceptor, and so that the gun stops being a reflex that costs battery and
returns nothing.**

Status: **staged, not implemented.** Every change here is physics, so it moves
the engine fingerprint and it moves the frozen exam. It lands as ONE revision,
with the viability sweep, or it does not land. See [Landing it](#landing-it).

---

## The one-line version

> A weapon that misses always, at no cost, teaches nothing. Make missing
> expensive and make aiming pay, and only then is there something to learn.

---

## What is true today, measured

Two weapons exist, different in kind rather than in size. The guided
interceptor is scarce and effective. The unguided gun is abundant and, so far,
inert.

| | unguided | guided |
|---|---|---|
| damage | 2500 of 10000, so four kill | 5000, so two kill |
| cost per shot | 20000 (200 J) | 100000 (1000 J) |
| magazine | **none** | 2, exactly enough for one drone |
| other limit | 20-tick cooldown | battery |
| speed | 61440/tick, plus the launcher's velocity | 81920/tick, homing |
| time to live | 100 ticks, ~300 m of reach | 15 ticks, ~60 m |
| lock range | n/a | 600 m, **ten times its reach, on purpose** |

⚠ **THE GUIDED COLUMN CHANGED ON 2026-08-09 AND THIS DOCUMENT'S ARGUMENT SURVIVES
IT.** It was a magazine of 4 and 150 ticks, so ~600 m of reach, in a 1000 m arena.
Everything below about scarcity, about the magazine being the cost of missing, and
about proximity damage being the reward for aiming, is unchanged and now bites
harder: two rounds is one kill's worth, so a wasted shot is half the drone's
offence rather than a quarter.

What is new is that the weapon no longer owns the arena. It reaches 60 m and locks
at 600 m, and the gap is the design: **a launch with no lock spends nothing**, so
matching the two would make holding `launch` high free and optimal. With the gap it
throws both rounds away ten times further out than they can reach.

⚠ **The gun has no magazine at all.** Battery would allow 396 shots; the
cooldown allows 60 in a 1200-tick fight. **60 is the real cap**, and battery
never binds.

### It is fired at the maximum possible rate

From one live raid, 22 drones with a gun in use, 145 published frames:

```
peak rounds in flight per drone:  5 5 5 5 5 5 5 5 5 4 4 4 4 3 3 3 3 3 3 2 2 1
frames with a round in the air:   145/145, 145, 145, 145, 142, 129, 126, ...
```

Steady state at maximum rate is 5 in flight (TTL 100 ÷ cooldown 20). **Nine of
twenty-two drones sit pinned at 5 for the whole engagement.** Four had a round
in the air in every frame of the fight. These drones are firing as fast as the
engine permits, from the first tick to the last.

### And it hits nothing

Health travels as a percentage, so an unguided hit is a drop of **25** and a
guided hit a drop of **50**. Same raid, 24 drones, 256 frames:

```
50   x28    guided hits, unambiguous
25   x 0    unguided hits
1-7  x48    wall impacts, which is impact_damage/1 and not a weapon
```

Twenty-eight interceptor hits and **not one gun hit**, while roughly twice as
many unguided rounds were in the air as guided ones. This is REGISTER D.14.

### Why: the envelope, measured

A shooter firing once with perfect aim at a target held still:

| range | 10 | 15 | 20 | 30 | 40 | 60 | 80 | 120 | 200 | 280 |
|---|---|---|---|---|---|---|---|---|---|---|
| | hit | hit | hit | hit | hit | hit | hit | miss | miss | miss |

Against something that manoeuvres it is far worse, and the design said so in
the `#intent{}` record before any of this was measured: at 60 m/s a shot needs
1.7 s to cross 100 m, and a target with 50 m/s² displaces about 70 m in that
time against a 2 m hit radius, so the release is **effective inside roughly
15 m and nowhere else**.

---

## ⚠ THE REAL DEFECT IS NOT THE ENVELOPE. IT IS THAT THE ENVELOPE IS A CLIFF

The above looks like a weakness to be tuned. It is not. It is a **reward
landscape with no gradient in it**, and that is a different kind of problem
which no amount of tuning the same shape will fix.

A controller that improves from firing at 200 m to firing at 100 m receives
**exactly zero** reward for the improvement. Both are a 0% hit rate. Selection
sees no difference between them, and no difference between either and firing at
the sky. It sees nothing at all until a drone is already inside ~15 m, which it
will essentially never reach by accident.

**Evolution cannot climb a step function.** The gradient the drones need does
not exist, so what they have learned instead is the only thing available: pull
the trigger whenever the cooldown allows, because a shot costs 200 J and an
unfired round is worth nothing later.

Two consequences worth stating plainly.

- The behaviour on the exhibit right now — swarms firing continuously into
  empty air — is **not** an artifact of being at generation 3. It is the
  optimum of the landscape as built. More generations will not fix it.
- Grading damage by RANGE would not fix it either, and this is the trap. Damage
  only pays out conditional on a hit, and hits do not happen out there to be
  graded. A range-graded gun is the same cliff with a nicer number written on
  the near side of it.

---

## Change 1: damage falls with MISS distance, as 1/d²

Raf's instinct was that damage should fall as d². Inverse-square is the wrong
law for the distance from the shooter — a bullet is one object carrying kinetic
energy, it does not spread, and what it really loses is velocity to drag,
which in this engine is nothing at all: `fly_one/2` is `x + vx` with no drag
and no gravity, so a round's energy is constant and constant damage is
self-consistent.

It is exactly the right law for the **other** distance. Energy leaving a point
and spreading over a sphere falls as 1/d², and that is a fragmenting or
proximity-fused round, which is what this weapon should have been all along.

```
        damage
          |
     2500 +----o                      o = direct hit, unchanged
          |     \
          |      \                    fragmentation, (r0/d)²
          |       `--.
          |           `----....___
        0 +---------------------------o----  miss distance
          0    hit    blast radius
             radius
```

**What this buys, and it is the whole point:** a controller that tightens its
aim from 50 m to 20 m to 5 m is rewarded at every step. The cliff becomes a
slope. There is now something to climb, and evolution is good at climbing.

It is worth being clear that this is the standard fix for a sparse-reward
landscape, arrived at here from the physics rather than from ML folklore. Both
routes give the same answer, which is a reason to trust it.

⚠ **Open, for the sweep, not for taste:** the blast radius, the exponent, and
whether the interceptor gets a proximity fuse too or stays hit-to-kill. A
proximity-fused interceptor is more realistic and strictly stronger, and the
defence does not obviously need to be stronger. Leaning to gun-only.

---

## Change 2: the gun gets a magazine

⚠ **A COOLDOWN IS A RATE LIMIT AND A RATE LIMIT CREATES NO DECISION.** Under a
pure rate limit, "fire whenever the cooldown is up" is strictly optimal, because
an unfired round is worth nothing later. There is no opportunity cost, so there
is nothing to be good at, so there is nothing to select for. That is precisely
what the measurement above shows: nine drones pinned at the cap for a whole
engagement.

A magazine creates **scarcity**, and scarcity creates a choice: spend this round
now, or keep it for a shot worth taking. That is a decision a controller can be
better or worse at, which means it is a thing selection can act on.

The interceptor already works this way and it is the contrast that makes the
case: magazine 2, two hits kill, so a full magazine is exactly one drone. That
weapon is deliberately scarce, and since 2026-08-09 it is scarcer — it was 4. The
gun has no equivalent, and it shows.

⚠⚠ **THE NUMBER IS A SWEEP DIAL, NOT A CHOICE.** Raf proposed 50. Against a
real cap of 60 that binds about half the swarm and shaves the top shooters by
roughly 17%, which is a trim rather than a decision. If the intent is genuine
scarcity the number likely wants to be lower. Charter rule 3 applies: it is set
on measurement with the whole sweep published, including the settings that made
the gun pointless. Range to sweep: **10, 20, 30, 50, 60 (today's effective
cap)**.

---

## ⚠ THE TWO CHANGES NEED EACH OTHER. NEITHER SHIPS ALONE

| | effect |
|---|---|
| magazine alone | rounds become scarce and still never hit, so selection removes firing altogether and the gun goes vestigial. A cheaper way to have no second weapon |
| proximity alone | aiming pays, but spraying is free, so spray-and-pray plausibly beats careful aim and the learned behaviour is the current one with better luck |
| **both** | proximity damage is the **reward for aiming**; the magazine is the **cost of missing**. A learnable weapon |

This is the reason this document exists as one design and not two tickets.

---

## What this does NOT change

- **The interceptor.** Scarce, effective, and already carrying its own decision.
  Leaning to no proximity fuse; the sweep may say otherwise.
- **The cooldown.** It stays. It is a rate limit and rate limits are fine as
  well as scarcity; what was wrong was rate limiting *instead of* scarcity.
- **Munition drag.** Still none, still deliberate. If range ever needs to matter
  honestly, drag is the mechanism and speed-based damage makes the falloff a
  consequence rather than a stipulation. Not now: it would add a second
  confound to the same sweep.
- **The comms channels.** Nothing here names a tactic, so charter rule 8 is
  untouched. "Closing to gun range" is not a channel, an actuator or a reward —
  it is what a slope with a magazine at the top of it produces on its own.

---

## Landing it

⚠ **This is physics, so it lands once, deliberately, with the sweep.**

1. It changes `airspace:limits()`, therefore the engine fingerprint, therefore
   islands on old code refuse islands on new code. That is correct behaviour and
   costs nothing: the fleet runs one image.
2. **It moves the frozen exam**, and that is the real cost. Charter rule 4: a
   rising number against a moving exam is an artifact. The ladder's history
   stops being comparable across the change, so the reset must be deliberate,
   dated, and stated on the page rather than discovered later.
3. It would kill REGISTER D.14's prediction if done first. D.14 is a written
   prediction currently under test — *if the gun is real, hits should appear and
   the fire rate should fall as the rosters mature.* Changing the weapon before
   reading it destroys the only evidence that would tell us whether any of this
   was necessary.

**Order:** rosters mature → read D.14 → run the viability sweep with all dials
together (station count, reach against starting geometry, ceiling, blast radius,
magazine) → land the revision and reset the exam in the same commit.

The dials now known to matter, and the register entry that found each:

| dial | why it is on the list |
|---|---|
| station count | the original sweep dial |
| reach vs. starting geometry | D.13 — raiders are confirmed on frame 1, so there is no approach phase to measure |
| ceiling | D.12 — a station's radius at altitude is sqrt(R² - z²), so the ceiling is a coverage parameter |
| blast radius | this document, change 1 |
| gun magazine | this document, change 2 |

A sweep over station count alone would have measured a saturated network at
every point and reported a smooth, confident, meaningless curve.

---

## What would falsify this whole document

If D.14 reads the other way — gun hits appear and the unguided fire rate falls
as the rosters mature — then the landscape had a gradient after all, the drones
found it, and both changes here are solutions to a problem that does not exist.
In that case this document is withdrawn and the register says so.

That reading is the next thing owed, and nothing here is built before it.
