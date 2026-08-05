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

Thirty-seven, in three blocks. Every one is a physical quantity, normalised to
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

**Comms, 8 channels.** Four friendly, four hostile. Their whole design is
[DESIGN_DRONES_THAT_TALK.md](DESIGN_DRONES_THAT_TALK.md).

## The actuator channels

Nine.

| # | channel |
|---|---|
| 1 | thrust forward, body frame |
| 2 | thrust lateral, body frame |
| 3 | thrust vertical |
| 4 | yaw rate command |
| 5 | release, above a threshold |
| 6 to 9 | the four transmitted comms channels |

Thrust is commanded in the **body frame** because that is what an airframe
takes. A world-frame velocity command would be a autopilot the export target
does not have.

Every output is clamped by the engine rather than trusted. A controller that
commands more than the airframe can do gets what the airframe can do, which is
the same contract a real flight controller offers.

## The brain

A `network_evaluator` network from `faber_tweann`, with **CfC hidden neurons**.

```erlang
network_evaluator:create_cfc_feedforward(37, [24], 9, tanh_table, ...)
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

At `{37, [24], 9}` that is 24 x 38 + 9 x 25 = 1137 weights, so about 2.3 KB at
16 bits each. A twelve-drone sortie is under 30 KB of genomes.

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
