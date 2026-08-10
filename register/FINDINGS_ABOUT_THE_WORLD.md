# Findings about the world

What this repository's simulated world turned out to be like. Every entry is something the code or the fleet did that nobody predicted.

⚠ **Every entry carries an ELI5 section. No exceptions.** `CHARTER.md` rule 10.
The index, and the rule itself, are in [`../REGISTER.md`](../REGISTER.md).

---

## D.20: the weapon's reach was set at the short end of a curve nobody had plotted

On 2026-08-09 the guided interceptor was cut from 600 m of reach to 60 m, and the
60 was chosen against one question: how short can it be before the missile stops
having the fuel to curve onto its target. That question has an answer, roughly
32 m, and 60 m clears it. **What was never measured is where 60 m sits against
the alternatives**, because `at_what_range_can_a_break_work.sh` steps 100 m to
200 m and prints identical tables for every reach in between.

Measured 2026-08-10 with the rungs narrowed, 24 starts per cell. The number is the
longest launch range that still connects:

| reach | 60 m | 80 m | 100 m | 120 m | 140 m | 160 m |
|---|---|---|---|---|---|---|
| vs a target running | — | 80 m | 100 m | 120 m | 140 m | 160 m |
| vs a target breaking | 50 m | 80 m | 100 m | 115 m | 130 m | 160 m |

Two things, and only the first was expected.

**A hard break costs the weapon between 0 and 10 m and never more.** Every arm
connects 100% at every range it can physically reach, on both evasions. The
pre-registered viability criterion — hit at 300 m, be beatable at 50 m, 40 points
between — **fails on all six arms including the shipped one**. `D.10` and `D.17`
said this about the turn rate and about time of flight; it is true of reach as
well, and it means viability does not choose this constant and cannot be made to.
Reach is the size of the kill zone, exactly, and picking it is a design decision
recorded as one rather than dressed up as a measurement.

**And the launch gate over-promises by the break margin, at every value.**
`drone_senses:reach_fraction/0` derives the gate from `speed * ttl`, the NOMINAL
reach, so a rung may fire in the last few metres where a breaking target lives:
10 m of the shipped 60, 5 m of the 120 it moved to. Smaller, not zero. Closing it
means gating on a measured fraction instead of on the arithmetic, which is a
different change and is not made here.

Set to 120 m, `INTERCEPTOR_TTL` 30. Twice the kill zone, 12% of a 1000 m arena
against the 6% before and the 60% at 600 m, and the lock range stays 600 m so the
5× gap that makes fire discipline a skill survives.

**It cost a lineage and moved the fingerprint, and both were paid rather than
worked around.** A `_g3` genome was bred to fly a fight decided inside 60 m, so
its fitness number does not transfer, which is the `_g2` argument about this same
constant — the lineage is `$dronex:roster_g4`, twelve hours after `_g3` started.
And physics sits inside `dronex_raid:fingerprint_parts/0`, measured `B582D158` →
`566C0420`, so the five islands roll together or they silently stop raiding each
other (`I.12`).

**ELI5.** We had shortened the arrow's flight to sixty metres, having only checked
that it was not so short the arrow fell out of the sky. We never checked what
eighty or a hundred and twenty would have been like. Having now checked: the arrow
always hits anything it can reach, ducking does not help at all, so the only thing
the distance decides is how close you must walk before shooting. We doubled it.

## D.19: the search could not reach three quarters of the memory it was given

Every drone carries 24 time constants, one per hidden neuron, and
`drone_genome:to_tau/1` maps them onto [0.05, 1.0). Low is a reflex, high is a
memory that lasts. `drone_pilot` says in its own docstring that memory is close
to a prerequisite here: a contact leaving the sensor cone cannot be tracked
without it, and leading a target needs to know where the target was.

Measured 2026-08-10 across all five rosters, 452 entries and **10,848 time
constants: not one was fast (below 0.2) or slow (above 0.8).** Only 2% to 7% had
left the band they were born in. Median lineage depth was 150 generations, so
this is not a young population that has not got going.

**It was arithmetic, and the two blocks of the genome were never on the same
scale.** One mutation is a draw at sigma 600 in gene units, on one gene in
twenty. A weight reads its gene as `gene/4096`, and was seeded uniform on
plus or minus 8192, so it starts spread across [-2, 2] and one nudge moves it
0.146, about 3.7% of that span. A tau reads the WHOLE 16-bit range as [0.05,
1.0), so the same seeded draw covered only the middle quarter, and one nudge
moves it 0.0087, about 0.9%.

So weights were seeded across the range they use and a gene near 2.0 left the box
on its first nudge, which is why every entry on every island carried weights
outside it. Time constants were seeded into the middle and had to cross 0.206 of
dead ground before being merely fast. At one gene in twenty over 150 generations
each tau had taken about 7.5 nudges, a random walk of sd 0.024, so the crossing
was 8.6 standard deviations. Reaching it at one standard deviation needs about
560 nudges, roughly **11,000 generations against the 150 available.**

Nothing was selecting against fast or slow neurons. They were never proposed.

**What it cost.** Every claim this repository might have made about whether
learnable time constants help was unanswerable, and would have read as "memory
does not pay" — a negative about a component that was never given the chance.
That is the same shape as the faber corpus's memory arc, recorded in the
2026-08-10 handover: a broken component manufactures exactly one kind of result.

**Fixed** by giving each block the draw and the step its own map deserves: taus
seeded across the full range, sigma scaled by the ratio of the two draw widths so
one nudge is the same fraction of each. It changes the distribution a lineage
starts from, so it shipped with a new lineage, `$dronex:roster_g3`.

**ELI5.** Imagine breeding dogs where you can choose coat colour and also size,
but the pen you draw your first dogs from only ever contains medium dogs, and
each generation can change size by a millimetre while it can change colour
completely. After a hundred generations you have every colour under the sun and
every dog is still medium. Somebody looking at your kennel concludes that size
does not matter for herding sheep. It might matter enormously. You never had a
big dog or a small one to find out with. The mistake was not in the breeding. It
was that "one step" meant a millimetre for one thing and a whole colour for the
other, and nobody had checked that the two steps were the same size relative to
what they were stepping through.

## D.18: a random controller could win rungs, and the weapon was paying for it

Under the 600 m interceptor, a null and eight random controllers used to take
rungs off both ladders: three of eight swept `circler`, `bruiser` and `marksman`
on the held-out set, which `I.23` recorded as "blind at the bottom" and read as
the rungs being too easy.

They are not too easy. On 2026-08-09 the interceptor's reach went from 600 m to
60 m, and the same reference controllers now win **0 of 48 on every rung of both
ladders**.

The two candidate causes were separated rather than argued about, because fights
also moved from opening 400 m apart to 800 m the same day:

| start set | separation | attacker wins, 6 controllers x 8 starts |
|---|---|---|
| `drone_starts` | 400 m | 0/48 |
| `distant_starts` | 800 m | 0/48 |

Identical, so it is not the geometry. It is the weapon.

What those wins were is now visible: hold `launch` high at a target that is
visible and inside weapon range from tick zero, and a missile that cannot be
dodged (`D.10`, re-confirmed at `D.17`) does the rest. No aiming, no closing, no
timing. A controller with random weights holds every output high about half the
time, so it got the free kill about half the time.

⚠ **SO THE BOTTOM OF BOTH LADDERS WAS MEASURING THE WEAPON, NOT THE CONTROLLER**,
and every rung order recorded before this date was graded partly on it. Both
orders are now void. They cannot be re-measured either, because grading a ladder
needs controllers that can tell rungs apart and every reference controller now
scores zero. Re-measure after the first population is bred against these physics.

**ELI5.** The test looked like it had easy questions and hard ones. It turned out
the easy ones could be passed by pressing a button that always worked, so pressing
buttons at random got you marks. The button was taken away. Now the same random
pressing scores nothing at all, which means the "easy questions" were never
measuring anything about the pupil.

## D.17: nothing can dodge the interceptor, at any range, and the sweep built to check that cannot see it

`D.10` recorded that the guided interceptor hits 100% of the time from 30 m to
450 m and that no setting of its turn rate fixes this while leaving the game
playable. On 2026-08-09 an argument was built on top of the opposite assumption —
that a longer time of flight gives a target room to swing out of the seeker's 60
degree field of view, so the weapon's reach must be long enough for a hard break
to work.

Measured, with fuel held at 600 m so nothing was limited by it:

| launch range | 30 m | 50 m | 100 m | 200 m | 300 m | 450 m |
|---|---|---|---|---|---|---|
| hit, target running | 100% | 100% | 100% | 100% | 100% | 100% |
| hit, target breaking | 100% | 100% | 100% | 100% | 100% | 100% |

A maximum-rate break never works. Time of flight buys a target nothing, so reach
cannot be chosen on counterplay, because there is none to protect. Reach decides
one thing only: **how close you must fly to earn a certain hit.**

⚠ **AND `sweep_the_interceptor.sh` COULD NOT HAVE CAUGHT THE MISTAKE**, which is
the part worth keeping. It varies the weapon's REACH and reads two numbers, hit
rate at 50 m and at 300 m. When reach is short the 300 m number goes to zero
because the missile **ran out of fuel**, which is indistinguishable in that table
from a target that dodged it. An instrument that collapses "was broken" and
"never arrived" into one column will confirm whichever of the two you already
believe. `at_what_range_can_a_break_work.sh` holds reach fixed and long, so every
number it prints is about guidance against manoeuvre.

**ELI5.** We thought a slower-arriving arrow gives you time to duck. We checked,
and ducking never works, at any distance. So how far the arrow flies is not about
fairness at all: it only decides how close you have to walk before you are
allowed to shoot.

## D.16: the fleet solved the frozen exam in about a day, once it could keep a lineage

On the morning of 2026-08-07 the islands were restored to keeping their
populations across a restart, for the first time since `roster_log` was written
(`I.21`). Within roughly a day of continuous breeding, four of five islands were
scoring 47 or 48 out of 48 on **every rung** of the frozen ladder.

| island | rounds | generation | wins per drill, of 48 |
|---|---|---|---|
| beam00 | 71,284 | 83 | 48 48 48 48 48 48 |
| beam01 | 69,538 | 21 | 48 48 48 47 48 48 |
| beam02 | 70,455 | 67 | 48 48 48 48 48 48 |
| beam03 | 71,709 | 97 | 48 48 48 42 48 48 |
| msi00 | 103,967 | 192 | 48 48 48 30 30 45 |

The day before, on the same ladder, beam01 had run 24, 23, 27, 3, 10, 24 and
beam00 46, 47, 47, 21, 24, 41.

⚠ **CORRECTION, 2026-08-08: THIS IS A READING OFF A CONTAMINATED INSTRUMENT.**
`I.22`: the six rungs are also six of the opponents the trainer breeds against,
so "solved the frozen exam" means solved a curriculum it was being selected on.
The entry is not withdrawn, because what it measured is real; it is performance
against the curriculum, and it may not be called improvement. The tidy story
that the leak explains the whole thing is already dead: beam03 and msi00 leak at
the same rate and sit at opposite ends.

**The exam is now exhausted as a measure.** A ladder every island clears at 99%
discriminates nothing, and the leaderboard's headline column has a fleet-wide
spread of two points. It needs harder rungs or it is decoration.

⚠ **DONE, 2026-08-08, AND IT WAS THE SAME FIX AS THE CONTAMINATION.** `drone_trials`
is a held-out ladder of six opponents that shoot AND close, which is the deficit
this entry identified. Champion totals on it span 120 to 276 of 288 against this
ladder's spread of two points. `I.23` has what it measures and where it is blind.

⚠ **AND `D.15` READS DIFFERENTLY IN THIS LIGHT.** The hundred-point swings were
recorded while lineages were being reseeded on every deploy, so the exam was
repeatedly measuring young, freshly seeded populations. That is a candidate
explanation and not a conclusion: the per-rung history now survives restarts and
can settle it.

⚠⚠ **THE ONE ISLAND THAT DID NOT SATURATE IS THE ONE THAT BRED MOST.** msi00 has
run 50% more rounds than anyone and is alone in failing `chaser` and `duellist`,
the two drills whose opponents shoot **and** close, while recovering against the
stationary `sniper`. More breeding, worse against a closing enemy. It is also
the only island whose radio ablation has never gone positive, across three
readings. Two thin signals pointing the same way, on the one machine that is not
a beam node and the only one running podman.

**ELI5.** A class was given the same six-question exam every week and nobody could
remember last week, so every week they sat it fresh and the marks jumped about.
Once they were allowed to remember, they got full marks on everything within a
day, and the exam stopped telling the teacher anything. One pupil, who had
studied the hardest of all, still cannot answer the two questions about someone
walking towards them.

## D.15: the frozen exam swings by a hundred points in a day, on a bred champion

`beam03` scored 288/288 one morning, 1/288 nine hours later, 27% by the evening
and 86% the next. The other islands sat in a band between 87% and 99% over the
same period.

The obvious explanation is dead. `roster:best/1` sits the exam, and `raid:absorb/3`
admits **captured** genomes into the same roster the champion is drawn from, so
the score could belong to a controller bred on another machine. The islands now
publish `benchmark_sitter`, and every island reporting these swings says
**`bred`**. Whatever is moving, it is the island's own lineage.

What that leaves, unresolved and written down so it is not rediscovered:

- The exam is sat by ONE genome. A roster whose best entry changes hands between
  two similar candidates would swing the published score without the population
  changing much at all.
- Captures enter with `fitness => 0` and become opponents in `trainer:opponents/1`,
  so absorbing a swarm changes the curriculum the champion is selected against.
  Grind and curriculum-shift are one treatment here, by design.
- The instrument itself may be at fault: 6 rungs × 48 starts is 288 deterministic
  outcomes of a single genome, with no variance estimate at all.

**ELI5.** A pupil sat the same exam every few hours and scored full marks, then
almost nothing, then most of the marks. The first guess was that a different
pupil had been sitting it. That has been checked, and it was the same pupil each
time. So either the exam is measuring something that genuinely changes that fast,
or the exam is not as steady an instrument as everyone assumed.

## D.14: the gun is fired constantly and appears never to hit

Raf asked whether the unguided rounds do any damage. They do, on paper: 2500
against 10000 of health, so four of them kill, where the guided interceptor does
5000 and two kill.

Whether one has ever landed is a different question, and the published recordings
answer it. Health is on the wire as a percentage, so an unguided hit is a drop of
**25** and a guided hit a drop of **50**. Over one live raid, 24 drones, 256
published frames:

    50  x28   guided hits, unambiguous
    25  x 0   unguided hits
    1-7 x48   wall impacts, which is `impact_damage/1` and not a weapon at all

Twenty-eight interceptor kills' worth of damage and **not one clean gun hit**,
while the same recording carries about twice as many unguided rounds in flight as
guided ones. The evolved controllers fire the thing constantly. The scripted
drills never fire it at all — zero unguided releases across all six kinds over
thirty-six benchmark fights — so the frozen ladder has never exercised it either.

⚠ **AND THE DESIGN SAID SO IN ADVANCE**, in the `#intent{}` record, before any of
this was measured: *"at 60 m/s a shot needs 1.7 s to cross 100 m, and a target
with 50 m/s² of acceleration displaces about 70 m in that time against a 2 m hit
radius. The unguided release is therefore effective inside roughly 15 m and
nowhere else."* Two weapons different in kind exist precisely because of that
arithmetic. What was not anticipated is that **a swarm would spend its battery on
the weapon anyway**: firing costs 200 J a shot, and at generation 3 selection has
not yet had the chance to remove a reflex that only drains it.

So this is not yet a defect. It is a prediction with a number on it: **if the gun
is real, gun hits should appear as the rosters mature, and the unguided fire rate
should fall.** If neither happens by the time the viability sweep runs, the honest
conclusion is that the second weapon is a battery tax with a muzzle flash, and it
should be either removed or given a reason to exist.

Recorded now, with n=1 raid, so that the later reading is a check against a
written prediction rather than a story told after the fact.

**ELI5.** A fighter plane carries a machine gun and a homing missile. Watching a
whole battle, every single kill was made by a missile, and the guns were fired
nearly twice as often as the missiles and hit nothing. The gun is not broken —
it works fine if you are almost touching the other plane — but nobody has learned
that yet, and firing it flattens your battery. The thing to write down today is
what we expect to see later: if the gun is worth having, pilots will get good at
it and stop wasting it. If they never do, it should not be on the plane.

## D.13: the network is never silent, so the threshold decides nothing

Publishing what the towers had confirmed, tick by tick, was meant to be an
exhibit feature. The first thing it printed was a problem.

A twelve-against-twelve engagement at the standard starts:

    frames 1200, first confirmed track at frame 1
    confirmed tracks over time: 5, 7, 7, 9, 10, 10, 10, 10, 10, 10, 10, 11

**Every raider is confirmed before the recording begins.** The drones start at
about x=300 and x=700 across the middle of a 1000 m arena at 60 m altitude, which
is inside two or three of the five 350 m domes on the first tick, and three
stations agreeing clears the evidence threshold in one look.

Four things this repository has written down stop being true in practice:

- *"The network is silent until a track is confirmed."* It is silent for zero
  ticks of a twelve hundred tick fight.
- *"Going loud is a decision rather than a default."* There is no decision. It is
  loud from the start of every engagement.
- *"An attacker can learn WHEN IT HAS BEEN SEEN."* There is nothing to learn: the
  answer is always yes, from tick one.
- *"The confirmation threshold is the interesting number."* Set it to one or to
  ten and nothing observable changes, because three stations report the same
  target in the same tick.

⚠ **AND IT SETS A TRAP FOR THE ABLATION.** A cue that is always present and
always says roughly the same thing is a near-constant input, and a near-constant
input carries almost no information no matter how useful the underlying fact is.
The ground arm would read close to zero and the honest-sounding conclusion —
*"cueing does not matter"* — would be wrong. The true statement would be
*"cueing was saturated"*, and the two are indistinguishable from the number
alone. This is the same shape as the item 6 result, where the ground arm read
zero because no network existed; a null from a saturated instrument and a null
from a disconnected one look identical.

**What follows for the viability sweep.** The dial was named as station count.
That is not enough. What decides whether raiding has an approach phase at all is
**reach against the geometry the fight starts in**, and the ceiling (D.12) is a
third. A sweep over station count alone would have measured a saturated network
at every point and reported a smooth, confident, meaningless curve.

Nothing here says the settings are wrong — a defender knowing its own airspace is
not a bug. It says the mechanics the design is proudest of are currently inert,
and that was invisible until the belief was drawn next to the truth.

**ELI5.** Someone built a burglar alarm with a clever rule: do not shout until
you have seen the intruder three times, so that a cat does not set it off. Then
they installed it in a small room with five cameras, and every intruder is seen
by three cameras the moment they step in. The clever rule never gets a chance to
do anything, and testing whether it works by turning it up and down tells you
nothing at all. The alarm is fine. The room is too small for the rule to matter.

## D.12: height buys silence, and the picture said the opposite

Asked whether coverage should be a dome, the answer was yes, and checking it
turned up a claim written in three places that was simply false.

A station tests **slant** range — the straight line from a mast on the ground to
a drone in the air — so its detection volume is a hemisphere and its radius at
altitude z is sqrt(R² - z²): 350 m on the floor, 180 m at the 300 m ceiling. The
code comments said the ring placement "leaves a genuine hole overhead". It does
not. Directly above the centre mast, the ceiling is 300 m away and the reach is
350: **covered**. The claim was written from the mental image of a searchlight
pointing sideways and never checked against the one line of arithmetic that
decides it.

What is true is more interesting. Measured over the published placement, five
stations, 1000 m arena:

| altitude | covered | covered by 2+ stations |
|---|---|---|
| floor | 84% | 46% |
| ceiling | 42% | 8% |

**Climbing roughly halves the chance of being seen and very nearly removes the
chance of being seen twice**, and the second number is the sharper edge. Stations
that agree confirm a target in about half the ticks a single station needs,
because a real target is reported at the same place by several masts while each
mast invents its own ghosts at its own position. The network is silent until a
track is confirmed. So height does not merely delay detection, it delays being
spoken about — and what the ground says is the only thing a defending swarm can
act on.

This is the first genuine tactic in the game that nobody designed. It was not put
there; it fell out of slant range meeting a ceiling, and it was invisible for as
long as coverage was drawn as a disc on the floor. A floor disc claims the
coverage at the ceiling equals the coverage at ground level, which overstates it
by a factor of two.

⚠ It also sets up the viability sweep, which now has a second dial nobody had
noticed: **the ceiling is a coverage parameter.** Raising it weakens every
station without moving one.

**ELI5.** Someone put five floodlights on the ground to light up a field, and
drew a map with five circles on it showing what was lit. The map was wrong in a
way that mattered: a floodlight standing on the ground lights a dome, not a
cylinder, so the higher you go the smaller the lit patch gets. Standing on the
grass you are in the light almost everywhere. Up at roof height, less than half
the field is lit, and the places lit by two lamps at once — where you are seen
quickly and certainly — have nearly vanished. The way past the lights was always
to go high, and the map had been hiding it.

## D.11: the Lamarckian arm was designed against a capability faber does not have

`DESIGN_THE_ROSTER_AND_THE_RAID.md` describes a fork in what a returning veteran
carries, and says **both are built, arm L is the default, and the choice is a
runtime dial**:

| arm | what is stored |
|---|---|
| **W** | the weights it took off with. Surviving is *evidence about* a genome |
| **L** | the weights it came home with. What it learned in the fight is heritable |

It names `evaluate_with_plasticity/3` as the mechanism. **That function does not
exist**, in faber or anywhere else.

⚠ **And the near miss is the interesting part.** `faber_tweann` DOES ship
`plasticity.erl`, `plasticity_hebbian.erl` and `plasticity_modulated.erl`, so a
directory listing says the capability is there — which is exactly the shape of
INHERITED-7, where a listing was read instead of a module and the answer was
wrong twice. Reading it this time:

    plasticity:apply_to_network(Module, Weights, Activations, Reward)
    weight_spec() :: {Weight, DeltaWeight, LearningRate, ParamList}

Those are **genotype-shaped** weights, one tuple per synapse carrying its own
learning rate. This repository's genome is a flat `[integer()]` quantized vector
driving `network_evaluator`, which offers `evaluate_with_state/2` and nothing
else. The two are not the same object, and the boundary test that forbids the
genotype path is deliberate.

**So arm L is not a dial, it is a build**, and a sizeable one: per-synapse
learning rates would have to enter the genome (changing its width, and therefore
every persisted genome and the engine fingerprint), activations would have to be
captured per tick, and the rule applied and converted back each frame.

**What shipped instead.** Arm W, described as the only arm rather than as a
choice. `raid:settle/3` says so where it returns the genome that took off. The
survivor-weights field still travels on the wire, because a wire format that
changes when a dial turns costs a protocol version, and a redundant field costs
bytes.

**ELI5.** The plan said the soldiers would come home changed by what they learned
and that we would simply choose whether to keep the change. It turns out nothing
about the way these soldiers are built lets them change during a fight at all.
The box on the shelf labelled "learning" holds a different kind of soldier
entirely. So they come home exactly as they left, and what we learn is which
ones came home.

## D.10: no setting of the interceptor is both viable and playable

The sweep D.6 asked for, with the criterion fixed before it ran:

> long range (300 m) hit rate at least 50%, close range (50 m) at most 40%, and a
> gap of at least 40 points between them.

That is the design's own claim, that a target which turns hard up close can beat
the interceptor and one engaged at range cannot. The whole sweep, after `D.8` gave
the seeker a field of view:

```
speed   turn   radius   rad/s    close%  long%   gap   viable
80m/s   7680    42 m    1.875      100    100      0   false      <- shipped
80m/s   3840    85 m    0.937      100    100      0   false
80m/s   1280   256 m    0.312       50    100     50   false
80m/s    960   341 m    0.234        0    100    100   TRUE
80m/s    640   512 m    0.156        0    100    100   TRUE
60m/s    960   192 m    0.312       50    100     50   false
60m/s    800   230 m    0.260        0    100    100   TRUE
120m/s  1280   576 m    0.208      100    100      0   false
160m/s  1280  1024 m    0.156      100    100      0   false
```

**The criterion can be met, below about 0.26 rad/s. Meeting it makes the game
unplayable.** At 640 a bred population ran 160 rounds and never left the floor:

```
round   0     0  0  1  0  0  0
round 160     0  0  2  0  0  0
```

against 120 rounds reaching `6,5,6,6,6,5` at the shipped value.

⚠ **The criterion measured the wrong situation, and that is the finding.** It
launched from a shooter holding station, already pointed at its target. That is
not how a controller uses the weapon. The setting that makes an interceptor fair
against a perfect launch makes it useless in the hands of an imperfect one, and
nothing in between satisfies both.

⚠⚠ **Speed makes it worse, which is the opposite of what the arithmetic
predicted.** A faster missile is less agile at the same acceleration and should be
easier to out-turn. It is not: at close range what decides a break turn is TIME OF
FLIGHT. At 160 m/s a 50 m shot arrives in a third of a second, in which a drone
turns 25 degrees, which breaks nothing.

**So the constant was reverted to the original and the defect is documented rather
than half-fixed.** `CLAUDE.md` caps this kind of iteration at two rounds; that cap
is spent, and a value chosen to make one number look right while breaking another
is exactly what charter rule 3 forbids. **D.6 stands open and it is a design
question, not a tuning one.**

**ELI5.** A guided missile in the game always hit, which made everything else
pointless. They worked out that making it clumsy enough to dodge is possible, and
tried it. Now nobody could hit anything with it at all, and the players stopped
getting better because there was nothing to get better at. There is no setting of
"how clumsy" that makes it both dodgeable and useful, so the problem is not the
dial. It is that the missile only has one dial.

## D.9: turn radius is the wrong quantity for a turning fight

`DESIGN_THE_AIRSPACE.md` argued the interceptor was beatable because **its turn
radius is worse than a drone's**: 42 m against 25 m. The number was right and the
quantity was wrong.

A turning fight is decided by **angular rate**, which is `a / v` and not `v / r`.
The missile turned at **1.875 rad/s** against the drone's **1.43**, so it
out-turned the thing it was chasing. A larger radius at a much higher speed is
still a faster turn in the sense that matters.

Measured before this was noticed: 100% hit rate at every range from 30 m to
450 m, and a sweep of the turn acceleration across five values, down to a radius
twenty-one times a drone's, did not move it by a single point.

**ELI5.** Two cars going round a roundabout. One is bigger and needs a wider
circle, so you would think the small one gets round first. But the big one is
going four times as fast, so it comes round sooner anyway. Comparing the circles
told them the wrong thing; what mattered was how quickly each one got all the way
round.

## D.8: a seeker that never loses lock is not a seeker

The guided interceptor steered toward its target for ever, with no field of view
of its own. In a bounded arena, a pursuer faster than its quarry that never loses
track **always reconnects**, however badly it overshoots.

It now looks forward from its own nose, 120 degrees, and a target that goes
beam-on or gets behind it breaks the lock for good. That is what a real seeker
does and it is a correctness fix rather than a balance one, which is why it was
kept when the balance change was reverted.

⚠ **It did not fix `D.6` on its own**, and the honest reading of what it did is in
`D.10`. What it did do is open the top of the frozen ladder: a bred population now
reaches `5,6,6,5,0,0` after 120 rounds instead of `6,5,6,6,6,5`, so the two
hardest rungs have headroom again.

**ELI5.** The homing missile could see in every direction at once and never lost
sight of what it was chasing, so dodging just delayed it. Real ones look out of
the front only, and if you get behind one it has no idea where you went.

## D.7: breeding works, and the frozen ladder is beaten inside 120 rounds

The first real measurement of the trainer. 24 seeded controllers, 120 steady-state
rounds, with the best entry sitting the frozen ladder every 30. Wins out of 6:

```
round   0     4  6  4  1  1  0
round  30     5  4  5  3  2  4
round  60     5  4  5  3  2  4
round  90     5  4  5  3  2  4
round 120     6  5  6  6  6  5
```

**The population improved against an exam it never trains on**, which is the one
thing item 4 was built ahead of item 5 to be able to say. Deepest generation 9,
roster full throughout.

⚠ **And it confirms `D.6` with a real population rather than random probes: the
ladder is very nearly beaten within 120 rounds**, which is minutes of wall clock.
The frozen exam has a useful life measured in an hour, not a month, and after
that it reports a flat line whatever the drones do.

The plateau from round 30 to 90 followed by a jump at 120 is worth noticing and
is NOT explained: it could be the search finding a new basin, or it could be the
6-start sample being too coarse to see steady progress. Both are testable and
neither has been tested.

**ELI5.** They taught the machines to fly by letting them compete, and checked
their progress against a fixed set of practice opponents nobody was allowed to
train against. The machines got better, which is the good news. The bad news is
that they beat the whole practice set in about two minutes, so from then on the
practice set says "full marks" no matter what happens next.

## D.6: the guided interceptor dominates, and it has now flattened two instruments

Eight random controllers over 16 starts, against the six-rung ladder:

```
null      0  0  0  0  0  0
seed 1   16 16 16 16 16 15     sweeps
seed 2    0  0  0  2  2  0     floor
seed 3   16 15 16 15 15 16     sweeps
seed 4   13 13 13  8  2  0     a clean curve
seed 5    2  1  3  0  0  0     near floor
seed 6    0  0  0  1  1  0     floor
seed 7   16 16 16 16 16 15     sweeps
seed 8    0  0  0  0  0  0     floor
```

Seed 4 shows the instrument has real resolution in the middle. The bimodality of
the rest is a property of RANDOM controllers, which either happen to fly or
happen to crash, and is not by itself a fault.

⚠ **What is a fault is that three of eight random controllers beat the hardest
rung 15 or 16 times out of 16.** A benchmark a random genome can max is
saturated before training starts, which is insight 054's failure exactly.

**The likeliest cause, stated as a hypothesis rather than a measurement:** four
homing interceptors per drone, two hits killing, against a target that does not
specifically evade a missile. An engagement then turns on who launches first
rather than on how anybody flies. This is the SECOND instrument the interceptor
has flattened: `D.4`'s first ladder graded on movement, and a homing weapon does
not care much whether a passive target hovers or circles.

**Not acted on, deliberately.** The interceptor was a design decision two turns
ago and its constants have never been swept; charter rule 3 says a constant is
chosen on viability with the whole sweep published, and quietly weakening it here
to make a number look better is exactly what that rule forbids. It is also the
third change to the game in one sitting, and `CLAUDE.md` caps that at two.

**ELI5.** They built a test track with easy corners and hard corners, to see how
well people could drive. Then they gave everyone a car that steers itself. Most
people got round every corner, including the hard ones, and the track stopped
telling you anything about drivers. The track is fine. The question is whether
the cars should steer themselves.

## D.5: the genome did not specify the controller

`network_evaluator:create_cfc_feedforward/5` draws a per-neuron **time constant**
from the process-global generator, and `set_weights/2` does not touch it. Two
networks built from the same genome came out with tau 0.625 and 0.359.

Found because the benchmark gave different numbers on two consecutive runs of the
same script on the same genomes.

**Three things were broken at once, and only one of them was visible:**

- the benchmark was not reproducible, which is what surfaced it
- a champion could not be rebuilt from its own genome, so selection at item 5
  would have been partly on unrecorded noise
- ⚠ **a genome sent to another island would have flown a different drone there**,
  which is the single property the whole wire format exists to provide, and the
  one that makes a raid mean anything

The fix is that the time constants are **in the genome**, one per hidden neuron,
appended after the weights, and `drone_pilot:from_genome/1` sets them explicitly.
That also makes them evolve, which is what a learnable time constant was supposed
to mean in the first place.

**The general shape:** a library that returns a fully-formed object from a
constructor plus a setter is telling you the setter covers the constructor. It
covered the weights. The test that now exists asks the only question that
mattered: does the same genome build the same controller, twice.

**ELI5.** They thought a recipe fully described a cake. It described the
ingredients, but the oven temperature was whatever the last person left it at,
and the recipe never mentioned it. The cakes came out different every time and
nobody could work out why, because everyone was staring at the ingredients. Worse,
posting the recipe to a friend was pointless: their oven was set to something
else entirely.

## D.4: the first ladder did not grade, and its order was guessed wrong

The frozen benchmark's six drills were hoverer, climber, orbiter, evader, jinker,
chaser: six behaviours that differed only in how they **moved**, and only the last
of which could shoot. Over 48 starts, two random controllers scored:

```
11  8 10 13 11 12
32 36 34 31 33 23
```

**Five of the six rungs were one rung repeated.** Only the chaser separated
anything, so the instrument was blind across most of its range, which is precisely
what insight 054 predicts of a benchmark that is not graded. It was measured
before anything had been bred against it, which is the only reason it could still
be changed at all.

The axis that measurably separates is whether the opponent **shoots**. The ladder
now runs three unarmed rungs then three armed ones.

⚠ **And the order was wrong a second time, for a reason worth keeping.** The
armed rungs were written sniper, chaser, duellist, on the assumption that a
stationary shooter is the easiest of them. It is the **hardest**: 3 and 2 wins out
of 48 against 22 and 8 for the chaser. **Closing costs aim, and a drill that only
shoots never pays it.** The rungs are now in the order the measurement put them
in.

**ELI5.** They built a set of six practice opponents, meant to get harder as you
went. Then they played them and found that five of the six were about equally
easy, so the practice set could not tell a beginner from someone decent. They also
found the one they had called easiest, a player who stands still and shoots, was
actually the hardest, because everyone else has to aim while running.

## D.3: a speed gate on an exit can be reached by crashing into it

Withdrawal was first written as *reach a lateral wall below 5 m/s and you leave
alive*. A test meant to confirm the opposite case, that arriving fast is still an
impact, found the drone **withdrawn**.

The mechanism was sound and the interaction was not. A wall impact is clamped,
and clamping sets that axis's velocity to zero. So a drone that flew into the
boundary at 17 m/s was, on the very next tick, sitting at the edge with one
tick's worth of acceleration behind it, which is below the gate. **Crashing was
the cheapest way to qualify as a controlled departure.**

The fix is that withdrawal is now a **hold**: slow, inside a 10 m margin, for two
seconds, with the clamp applied first and the exit checked after. That cannot be
arrived at by accident, and it makes leaving cost what it should, which is two
seconds of slow predictable flying at the edge of the map while somebody may be
shooting at you.

**The general shape, which is what makes this worth an entry:** a gate on an
instantaneous quantity is a gate on a quantity that some other rule may be
setting to a convenient value. The clamp and the exit were each correct alone.

**ELI5.** The rule was "if you are moving slowly when you reach the fence, you
may step over it and go home". Someone sprinted at the fence and bounced off it.
For a moment afterwards they were standing still next to the fence, which is
exactly what the rule asks for, so they were allowed home. The rule now says you
have to walk slowly near the fence for a while first. You cannot do that by
accident, and you certainly cannot do it by running into it.

## D.2: the model settles on the analytic terminal velocity exactly

At full thrust against quadratic drag the speed converges to `sqrt(max_accel *
drag_div)` and then **stops there to the unit**: 35840, which is 35 m/s. Not
close to it, equal to it, because at that speed the integer drag term is 2560
and the net acceleration is exactly zero.

Worth recording because it is what the whole fixed-point unit scheme was chosen
for, and because it makes the test an equality rather than a tolerance. A
tolerance would have passed against a drag constant wrong by a few percent.

**ELI5.** Push a shopping trolley as hard as you can and it stops speeding up at
some point, because the faster it goes the harder the air pushes back. You can
work out that top speed on paper before you push. Here the number on paper and
the number the model reaches are the same number, exactly, with nothing rounded
off in between.

# I: findings about the work

## D.1: the arena's walls kill a drone flying flat out, and that is the physics

A test meant to check terminal velocity ran a drone at full forward thrust for
400 ticks and found it dead. Not from the fall, and not from a bug: at 35 m/s
from the middle of a 1000 m arena it reaches the far wall at about tick **286**,
and a drone that keeps commanding thrust into a surface keeps being clamped,
keeps losing that tick's speed to the wall, and keeps taking the damage that
speed was worth. Dead by tick 300.

That is `bounded/1` behaving exactly as designed, and it makes the arena's edge a
thing to respect rather than a place to park. It is written down because it is
the first emergent consequence this engine has produced, because the first
version of the test was silently measuring it, and because a controller that
learns to hug a wall will meet it.

**ELI5.** They wanted to know how fast the drone could go, so they held the
throttle down and waited. It got up to speed in five seconds, kept going, and
flew into the far wall of the room. Because nobody let go of the throttle, it
kept pushing against the wall until it broke. The measurement was fine. The room
is just smaller than the test was patient.

