# The drone

**This exists so a controller can be evolved here, checked by a stranger, and
then exported and flown somewhere that is not here.**

---

## Three parts, and only one of them evolves

| part | evolves | why |
|---|---|---|
| the **body** | no | one airframe, so a fight is between tactics rather than between loadouts |
| the **sensor suite** | no | fixed width is what makes one population of genomes interchangeable, exportable and comparable |
| the **brain** | **yes** | weights, and optionally the time constants |

⚠ **This is the deliberate opposite of the sibling worlds**, where which organs
exist is the genotype. `hecate-biotope/COMPARISON_FABER.md` rejected faber's
domain SDK on exactly that ground: two creatures alive at the same instant have
different input widths, so no population-wide I/O can be declared.

**Here the declaration is correct.** Every drone has the same channels, so the
genome is a weight vector of fixed length, which is what makes it small on the
wire, comparable across islands, breedable by a plain vector operator, and
exportable to ONNX. Fixed width is not a limitation borrowed from faber; it is
the property the whole design is built on.

## Perception is a boundary, and the boundary is a shape

A controller sees **what its sensors report and nothing else**. It never touches
the arena.

```erlang
act(Genome, PilotState, #drone{} = Self, #contacts{} = Seen) -> ...
```

⚠ **The function destructures the arena to its contact list and to nothing
else.** The full arena is out of scope below that line, so a controller cannot
reach another drone's true position even by accident. The defence is the
destructuring. A comment would not survive a refactor; a shape the compiler
checks will.

Every reading is derived by the sensor model, which is a module with a declared
degradation, inherited from the counter-UAS line's `dronex_sensor_model`
behaviour. That is the mechanism by which a **characterised real sensor** can
one day replace the simulated one without anything downstream changing. See
[DESIGN_THE_SECOND_ACT.md](DESIGN_THE_SECOND_ACT.md).

## The sensor channels

Forty-one, in three blocks. Every one is a physical quantity, normalised to
roughly minus one to one.

**Proprioception, 8 channels.** What a drone knows about itself, all of it
available on a real airframe from an IMU, a barometer and a battery monitor.

| # | channel |
|---|---|
| 1 | battery remaining |
| 2 | speed |
| 3 | vertical speed, signed |
| 4 | altitude above ground |
| 5 | distance to the nearest arena boundary |
| 6 | health remaining |
| 7 | yaw rate, signed |
| 8 | damage taken since the last tick |

⚠ **Channels 1, 6 and 8 are the self-diagnosis a drone needs to decide it is
losing**, and they are why withdrawal needed a mechanism rather than a sensor:
the information to choose retreat was already here, and what was missing was
anywhere to go and any payoff for going there.

Channel 8 is the only proprioception of being shot, and it **conflates** being
hit, hitting a wall and colliding with another drone. That is stated as a
limitation rather than fixed: a real airframe cannot cleanly tell those apart
either, and separating them here would be giving the controller information the
export target will not have.

**Contacts, 21 channels.** The three nearest contacts inside the sensor cone,
seven channels each.

| channel | note |
|---|---|
| bearing sin, bearing cos | two channels rather than one angle, so there is **no discontinuity at the wrap point**. A single bearing channel jumps from one extreme to the other as a target crosses the nose, and a network has to spend capacity learning that the jump is not real |
| elevation sin, elevation cos | same reason, vertically |
| range | |
| closing rate, signed | |
| affiliation | +1 friendly, -1 hostile, 0 unresolved |

An empty contact slot reads as all zeros with range at maximum, so *nothing
there* and *something at the edge of range* are distinguishable.

⚠ **The controller does not predict.** Channels report where a contact is now,
never where it will be. Solving intercept is strategy and it is withheld, so
"learned to lead a target" stays a thing this substrate can find rather than a
thing it was handed.

**Comms, 12 channels.** Four friendly air, four hostile air, four **ground**.
Their whole design is
[DESIGN_DRONES_THAT_TALK.md](DESIGN_DRONES_THAT_TALK.md).

The ground bank carries the defending island's static sensor network, which
transmits its tracks rather than being wired into a privileged input. That is
what keeps attackers and defenders on **one genome shape and one roster**, and
it is argued in
[DESIGN_THE_STATIC_DEFENCE.md](DESIGN_THE_STATIC_DEFENCE.md). An attacking drone
hears the defender's network on the same bank, because you hear a radio and
where you are tells you whose it is.

## The actuator channels

Ten.

| # | channel |
|---|---|
| 1 | thrust forward, body frame |
| 2 | thrust lateral, body frame |
| 3 | thrust vertical |
| 4 | yaw rate command |
| 5 | **release**, above a threshold. Unguided, cheap, knife range |
| 6 | **launch**, above a threshold. Guided interceptor, needs a lock, magazine of two |
| 7 to 10 | the four transmitted comms channels |

⚠ **Two weapons rather than one, and the earlier rule is withdrawn on
arithmetic.** An unguided shot at 60 m/s needs 1.7 s to cross 100 m and a target
pulling 50 m/s^2 displaces about 70 m in that time against a 2 m hit radius, so
one unguided weapon is a knife-fight weapon and nothing else. The release rewards
closing; the interceptor rewards seeing first. Argued in
[DESIGN_THE_AIRSPACE.md](DESIGN_THE_AIRSPACE.md).

⚠ **There is no `withdraw` actuator**, although a drone can leave the engagement
alive. Charter rule 8: no channel may name a tactic. Retreating is flying
somewhere at a speed, which channels 1 to 4 already express, and the decision to
do it rests on battery, health and damage, which the proprioception block already
reports.

Thrust is commanded in the **body frame** because that is what an airframe
takes. A world-frame velocity command would be a autopilot the export target
does not have.

Every output is clamped by the engine rather than trusted. A controller that
commands more than the airframe can do gets what the airframe can do, which is
the same contract a real flight controller offers.

## The brain

A `network_evaluator` network from `faber_tweann`, with **CfC hidden neurons**.

```erlang
network_evaluator:create_cfc_feedforward(41, [24], 10, tanh_table, ...)
```

**Memory is not a garnish here, it is close to a prerequisite.** Three of the
things this repository exists to look for are unavailable to a feedforward net:

- **a signal is only useful if it can be held.** A feedforward drone that hears
  something can react on the same tick and never again, which is reflex rather
  than tactics
- **intermittent observation.** A contact that leaves the cone vanishes from the
  inputs entirely, and without state there is nothing to track it with
- **leading a target.** Predicting where something will be requires knowing
  where it was

CfC gives per-neuron internal state with a learnable time constant, evaluated in
closed form rather than by integrating an ODE, and it is already in the library
with a Rust NIF behind it.

**Plasticity is available and is off by default.**
`network_evaluator:evaluate_with_plasticity/3` and `evaluate_with_neuromod/4`
change weights from activity and from a reward signal **during** an episode. A
drone that flies a raid can genuinely come home with different weights from the
ones it took off with.

⚠ That makes "combat experience" literal rather than figurative, and it turns
what a veteran carries into a real fork. It is argued where it belongs, in
[DESIGN_THE_ROSTER_AND_THE_RAID.md](DESIGN_THE_ROSTER_AND_THE_RAID.md).

`reset_internal_state/1` is called at the start of every engagement. A drone
that remembers the previous fight would make the benchmark depend on the order
its exams were run in.

## The genome on the wire

```
{Layers, Weights}   Layers  :: [pos_integer()], widths in order
                    Weights :: [integer()], quantized, bias-then-weights
                               per neuron, neurons in order, layers in order
```

**No floats and no maps anywhere in it.** `term_to_binary` is not canonical over
maps, so a content hash of a genome carrying one is not stable between two
processes. Over tuples and integer lists it is, so packing is one call and the id
is `sha256` of the packed form.

⚠ **The quantized form IS the genome, not a compression of it.** The trainer
proposes floats; quantization happens at admission to the roster; what is
stored, flown, published and exported is the quantized value dequantized back.
Otherwise the id published for a fight identifies something slightly different
from the thing that flew.

At `{41, [24], 10}` that is 24 x 42 + 10 x 25 = 1258 weights, so about 2.5 KB at
16 bits each. A twelve-drone sortie is about 30 KB of genomes.

⚠ **One shape for both sides, and it is not negotiable for a convenience.**
Giving a defender extra channels for a ground cue would mean two genome shapes,
two rosters and two populations that cannot be drawn from one pool. A sortie is
a draw from the roster rather than an assembly of declared roles, and a captured
genome has to be usable by its captor. That is why cueing goes over comms.

**A foreign genome is validated and rejected, never repaired.** Clamping a
stranger's weight into range changes the genome, which changes what actually
fought, which means the id published no longer identifies the code that ran. The
limits are a denial-of-service defence rather than a quality bar: a host runs a
stranger's network up to the turn cap times per drone, so the cost of a raid is
linear in the weight count.

Refusals are counted and published. An island that refuses everything and an
island nobody attacks look identical otherwise.

## Export, which is the point of the framing

`network_onnx:to_onnx/1` takes the same network record and emits ONNX opset 18.
A champion therefore leaves the BEAM and runs under onnxruntime in Python, C++,
JavaScript, or on the airframe.

**Order-of-work item 9 is a test, not a claim:** export a champion, load it
through onnxruntime, drive it through the same start geometries, and assert the
same trajectories. That is what makes *virtual environment for potentially
real-world drone AI* a sentence with a file behind it.

⚠ It also constrains the sensor design retroactively, which is why the channels
above are all quantities a real airframe can produce. A channel that only a
simulator can compute would make the export a toy.
