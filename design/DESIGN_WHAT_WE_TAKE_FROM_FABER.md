# What we take from faber, and what we do not

**This exists so the line between this repository's domain and a neural-network
library is drawn once, on evidence, and not redrawn every session.**

---

## The rule that this document is an application of

`CLAUDE.md`: *when the source code of a dependency is available, ALWAYS do a deep
study before using it*, with *guess at API from function names* named as the
anti-pattern.

⚠ **That rule was broken twice on this question and the record is kept here so it
is not broken a third time.**

`hecate-biotope/COMPARISON_FABER.md` records the first: faber-neuroevolution was
described as "an app and a supervisor" after listing only `src/*.erl`, when it is
about 44,000 lines across fifteen subdirectories.

The second was during this repository's design. The conclusion *hecate-dronex
needs no faber dependency at all, we would write our own forward pass in about a
hundred lines* was reached after reading `robo_net`, the strategy modules and the
DXNN process-graph path, and **without opening `network_evaluator.erl`**, which
is the largest module in faber-tweann at 1,053 lines and is precisely the thing
claimed not to exist. Both errors have the same shape: a directory listing
treated as a survey.

## `network_evaluator` is not the process-graph phenotype

Its own docstring: *synchronous (blocking) forward propagation. Unlike the
process-based cortex/neuron approach used during training, this is designed for
fast inference in real-time applications like games.*

| it has | what that is here |
|---|---|
| `create_feedforward/3,4,5` | a controller from `{In, Hidden, Out}` |
| `evaluate/2` | the forward pass |
| `get_weights/1` -> flat `[float()]`, `set_weights/2` | **the genome as a vector.** This is the seam a vector operator needs, and it already exists |
| `to_binary/1`, `from_binary/1`, `to_json/1`, `from_json/1` | serialization for the roster |
| `create_cfc_feedforward/5`, `evaluate_with_state/2`, `reset_internal_state/1` | LTC/CfC neurons with per-neuron internal state and a learnable time constant |
| `evaluate_with_plasticity/3`, `evaluate_with_neuromod/4` | weights that change **during** an engagement |
| `compile_for_nif/1`, `faber_nn_nifs:evaluate_batch/2`, `cfc_pop_step/3` | Rust acceleration, including stepping a whole population of CfC networks in one call |
| `get_viz_data/3` | visualization data straight out of the evaluator |
| `network_onnx:to_onnx/1,2` | ONNX opset 18 export |

Version 2.0.1. `native/faber_nn_nifs` is present. CfC in the evaluator landed in
1.2.0.

## Three of those decide the design, not merely the build

**ONNX makes the charter's framing true rather than aspirational.**
`network_onnx:to_onnx/1` takes the same network record the controller is. A
champion therefore leaves the BEAM and runs under onnxruntime in Python, C++,
JavaScript or on an airframe. Writing our own integer network would mean
discarding that or writing a protobuf ONNX exporter ourselves.

**CfC state is close to a prerequisite for evolved communication.** A
feedforward drone that hears a signal can react on the same tick and never
again, which is reflex rather than tactics. The full argument is in
[DESIGN_THE_DRONE.md](DESIGN_THE_DRONE.md).

**Plasticity makes a returning veteran literally changed**, which turns what a
survivor carries from a naming quibble into a real Lamarckian fork. Argued in
[DESIGN_THE_ROSTER_AND_THE_RAID.md](DESIGN_THE_ROSTER_AND_THE_RAID.md).

## The one real cost: floats, and the split that answers it

`functions:tanh/1` is `math:tanh/1`, which is libm, so the evaluator is **not
bit-portable across machines**. That is exactly what the retiring `robo_net`
bought with Q12 and a checked-in table.

It is narrower than it looks. Float `+`, `*` and `-` are exact under IEEE754,
BEAM uses SSE2 doubles with no extended precision, and Erlang does not reorder
float arithmetic, so **the transcendental is the only source of divergence**. A
table-based activation removes it, and `network_evaluator` already takes
`activation :: atom()` and dispatches through `functions`, so it is one function.

| path | used for | exact across machines |
|---|---|---|
| Rust NIF, `math:tanh` | training, where throughput matters | no, and it does not need to be |
| pure Erlang, table activation | the published fight | yes |

faber-tweann already keeps a pure Erlang reference held in agreement with the
native path by a conformance test, so the pattern exists rather than being
invented here.

## What is genuinely not usable, with the evidence

**`faber_neuroevolution/src/distribute/macula_mesh.erl` is a stub against a dead
API.** It looks like distributed evolution over our mesh and is not:
`start_macula_peer/2` carries the comment *"This is a placeholder - actual macula
integration would go here"*, the real path sits behind `-ifdef(MACULA_MESH_ENABLED)`
and calls `macula_peer:start_link/1`, which does not exist in macula 7.x, and the
dependency is commented out in `rebar.config` at `{macula, "~> 0.14.2"}`, six
major versions behind. Our mesh work is `hecate_om` plus `macula` directly, as the
siblings do.

**`communication_silo` is a tracker, not a transport.** `send_message/4` is a
`gen_server:cast` that records statistics for the meta-controller; it carries
nothing between evolved agents. Its **measurement vocabulary** is worth taking as
design: vocabulary size, dialect formation, coordination success, honesty against
deception.

**`neuroevolution_server` and the strategy modules are the wrong shape**, not the
wrong quality. Every strategy owns its own scheduling as a generational or
steady-state loop, and this island already has a `gen_server` with two timers
that must keep publishing and keep answering raids whatever the search is doing.
So the selection and variation loop is ours, at roughly 200 lines over
`get_weights` and `set_weights`.

**`checkpoint_manager` is more capable than an earlier note recorded**, and the
correction matters: it has `save_checkpoint/2,3`, `load_checkpoint/1`,
`load_latest/0,1`, `load_best_fitness/0,1`, `list_checkpoints/0,1` and
`prune_checkpoints/1`, and it serialises through `network_evaluator:to_binary/1`.
That nobody calls `load_*` in its own `src/` is a fact about usage, not
capability. We still keep the roster in reckon-db rather than in files, because
the roster is queryable state with provenance rather than a series of snapshots,
but the shape is worth reading before writing ours.

## The boundary, stated once

**In this repository, because it is the domain:** the flight and combat engine,
the arena, the sensor and actuator channels, the perception boundary, the comms
channel and its aggregation, the genome wire format and its validation, the
scripted drills, the start geometries, the frozen benchmark, the trainer, the
roster, the raid protocol, the island loop and the `hecate_om` spine.

**Nothing about drones lives anywhere else.**

**From `{faber_tweann, "~> 2.0"}`, because it is a neural-network library:**
`network_evaluator` as the controller, CfC for memory, plasticity for in-flight
learning, the NIFs for training throughput, `network_onnx` for the export
bridge, and `novelty_strategy`'s archive design for the discovery instrument.

⚠ **Pin at 2.0.1 or later.** 2.0.0 is published and unbuildable: it shipped
without `native/`, so `priv/build-nifs.sh` hard-errors. 1.x carries a broken ONNX
export, a silent NIF fallback and four NIF contract bugs.

**`robo_*` is not used and is untouched by any of this.** It can disappear from
faber-tweann without affecting a line here. The debt to it is a **design** debt
and it is credited rather than linked: the perception boundary enforced by
destructuring rather than by comment, a canonical wire format over tuples and
integer lists, validating a stranger's genome rather than clamping it, and the
start set as a rule of the game rather than a test fixture.

## Costs of the dependency, stated rather than glossed

- **Release cadence coupling.** faber-tweann is a research engine and it moves.
  Mitigated by a loose constraint, by using only the inference and serialization
  surface, and by the fact that the alternative is maintaining a fork of 1,053
  lines plus an ONNX exporter plus NIFs.
- **Rust in the build.** Already required: macula's QUIC and crypto NIFs are the
  price of subscribing at all, so the toolchain is in the container regardless.
- **Mnesia in the application list.** `faber_tweann` lists it. The genotype path
  uses it; the `network_evaluator` path does not. Nothing here calls
  `genotype:init_db/0`, and a test asserts that no Mnesia table is ever created.

## An earlier judgement that reverses

`COMPARISON_FABER.md` rejected faber's domain SDK for biotope on one decisive
fact: `agent_definition:network_topology/0` fixes `{Inputs, Hidden, Outputs}` at
compile time and `agent_bridge` throws `topology_mismatch`, while biotope's
central claim is that the sensor suite itself is what evolves, so two creatures
alive at the same instant have different input widths.

**That objection does not apply here.** Every drone has the same channels, so the
SDK's central assumption holds. This does not mean adopting the SDK's training
harness, for the scheduling reason above, but it does mean the *discipline* of
sensors and actuators as declared modules with `input_count/0` and
`output_count/0`, validated against the topology, is a shape that fits, and it is
the same discipline as the counter-UAS line's `dronex_sensor_model` behaviour
this repository is keeping.
