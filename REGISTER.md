# The register

**This exists so a finding, or a mistake, is written down once and not paid for
twice.**

Two series. `D.n` is a finding about the world this repository simulates.
`I.n` is a finding about how the work itself went wrong.

---

## ⚠ EVERY ENTRY CARRIES AN ELI5 SECTION. NO EXCEPTIONS.

`CHARTER.md` rule 10. Every entry ends with **ELI5**: the finding in plain
language, for somebody who knows none of this.

**Written in the same commit as the entry, by whoever wrote the entry.** An
explanation written elsewhere and afterwards is a translation, and translations
drift. One written in the same commit cannot.

It is a comprehension test before it is outreach. **If the finding cannot be
explained without the vocabulary, it is not yet understood.** No jargon, and no
term defined only elsewhere in this repository.

## It has split, and this is the index

The rule was "one file until it passes about 800 lines, then one file per series
under `register/`, with this file becoming the index." It reached 1,655 and the
split happened on 2026-08-08.

| Where | What |
|---|---|
| [`register/FINDINGS_ABOUT_THE_WORK.md`](register/FINDINGS_ABOUT_THE_WORK.md) | the `I` series: how the work itself went wrong |
| [`register/FINDINGS_ABOUT_THE_WORLD.md`](register/FINDINGS_ABOUT_THE_WORLD.md) | the `D` series: what the simulated world turned out to be like |

⚠ **THE `I` SERIES IS ALREADY AT 909 LINES**, so the rule bites again the moment
it has anything to split ALONG. Series is the only axis this register has, and
splitting one series by date would file two entries about the same fault in two
places. Left as is, and said out loud rather than discovered later.

⚠⚠ **`I.11` WAS TWO DIFFERENT FINDINGS AND IS NOW ONE.** The island that
advertised once and could never be raided became `I.24`; the island that stopped
while reporting healthy keeps `I.11`, because it had the number first and
renumbering it would have invalidated citations that were correct when they were
written. `scripts/split_the_register.py` did both, and the index below is
generated from the headings so it cannot drift from what the files hold.

---

# Inherited

**These were paid for elsewhere and will bite here.** They are marked
`INHERITED` rather than numbered into either series, because this repository did
not earn them and claiming them would make the register a reading list.

The numbering in the sibling registers is not continued: `hecate-society`
continues `hecate-biotope`'s because their entries are cross-referenced
everywhere, and this track shares neither.

### INHERITED-1: a catch-all clause turns a wrong pattern into silence

A reader matched `{macula_event, Ref, Topic, Payload}`. **The SDK sends five
elements**, with a `meta` on the end. Every fact fell through
`handle_info(_Msg, S)` and was discarded without a log line, for an hour.

Everything checkable checked out: 226 published and 0 failed, both ends agreeing
on the realm byte for byte, the same topic, the same namespace, every link
healthy, and a sibling page receiving facts throughout.

Two things found it, neither a test: a **third-party subscriber** run from a
laptop, which is the only thing that separates *publisher silent* from
*subscriber deaf*; and **reading the output instead of the summary**, because
that script printed `(other message: macula_event)` fifteen times and then
concluded `NOTHING ARRIVED`.

**Applied here as charter rule 6:** anything read off a wire gets a test that
pushes the real message through the real handler, and that test is verified to
go red without the fix.

**ELI5.** They set up a letterbox that only accepted envelopes with exactly four
things written on them. The post office had started writing five. Every letter
was quietly thrown away, and every check they ran said the post was working,
because the post office really was sending letters and the letterbox really was
there. What found it was someone standing outside with their own letterbox.

### INHERITED-2: a physics constant in a deployment repo is a version handshake nobody performs

A node config set a world constant that lives in the service's own source. The
node pulled the config naming that constant **before** it pulled the image that
had it, and the service refused to start on an unknown key rather than ignoring
it. That refusal is correct and is not the fault. The fault is that a physics
constant sat in another repository on another release cadence.

Two of three nodes sat in a boot-crash loop for two hours. Exactly one island
being alive was the only symptom.

**Applied here as charter rule 2.**

**ELI5.** The rulebook for the game lived in one box and the players lived in
another, and the boxes were delivered on different days. On the day the rulebook
arrived first, the players opened it, found a rule mentioning a piece they did
not have, and refused to play. They were right to refuse. The mistake was
shipping the rulebook separately from the pieces.

### INHERITED-3: a guard never seen to fail is not known to be a guard

A boundary check that has never been observed to reject anything is a comment
with a function's syntax. The sibling has
`scripts/prove_the_guards_bite.sh`, which breaks four boundaries one at a time
and asserts each goes red.

Related, and both recurred: a perturbation that only breaks the **compile**, for
instance an unused variable under `warnings_as_errors`, is not a red check; and
`cp` restoring a `.bak` leaves an older mtime, so rebar3 serves a **stale beam**
and the suite passes against code that is no longer there.

**ELI5.** A smoke alarm you have never heard go off is not a smoke alarm you know
works. Once in a while you have to hold a match under it.

### INHERITED-4: an invariant that holds only in expectation is not an invariant

A test asserted that a diversity measure never decreased. It usually did not, and
occasionally it did, for reasons in the mathematics rather than in the model. A
red test looked like a broken model for a day.

**The fix was to find the quantity that really is monotonic** and assert that
instead, rather than to loosen the assertion until it stopped failing.

**ELI5.** If you say the tide always comes in, you will be wrong twice a day.
Saying the moon keeps going round is the thing that is actually always true.

### INHERITED-5: a mirrored field order is a fault waiting for an append

A publisher sent flat lists whose meaning was positional, so every reader
mirrored the field order in its own source. A new field was appended, one reader
did not follow, and **the earlier indexes went on decoding correctly**, so
nothing looked wrong.

**Applied here:** names travel with vectors, and `fact_version` bumps on every
shape change including an append.

**ELI5.** Two people agreed that the third number on the page is the price.
Someone added a number in the middle. Now one of them is reading the weight and
calling it the price, and neither of them notices, because a weight looks like a
price.

### INHERITED-6: the site must not run the engine

A spectator page was built to recompute what another service had already
computed, on the argument that shipping every frame was too expensive. The
premise was true and the conclusion did not follow: nobody wanted every frame,
and one featured fight is unremarkable in size.

The cost was that the game engine ended up inside a content website,
version-locked to one node, with every spectator repeating identical work.

**Applied here:** a raid is published as a recording. See
[design/DESIGN_THE_MAP.md](design/DESIGN_THE_MAP.md).

**ELI5.** Rather than filming the match and posting the video, they posted the
teams and asked every viewer to replay the game themselves. Everyone got a
slightly different match, and the league had to make sure every viewer owned the
same rulebook forever.

### INHERITED-7: guessing a library's API from a directory listing, twice

Recorded in full in
[design/DESIGN_WHAT_WE_TAKE_FROM_FABER.md](design/DESIGN_WHAT_WE_TAKE_FROM_FABER.md),
because that is the document the error produced and a finding belongs beside the
decision it changed.

Short form: faber-neuroevolution was described from `src/*.erl` alone when it has
fifteen subdirectories, and faber-tweann was declared to lack a flat network
evaluator without opening `network_evaluator.erl`, its largest module, which is
exactly that. Both errors have one shape: **a directory listing treated as a
survey.**

**ELI5.** Someone said the library did not have a hammer, having looked only in
the top drawer. There were three hammers in the drawer underneath. The rule is
to open every drawer before saying what is not in the toolbox.

## The entries

### `I` — findings about the work

In [`register/FINDINGS_ABOUT_THE_WORK.md`](register/FINDINGS_ABOUT_THE_WORK.md), newest first.

| | |
|---|---|
| [`I.25`](register/FINDINGS_ABOUT_THE_WORK.md#i25-two-counters-that-could-never-count-and-one-of-them-made-the-central-claim-unobservable) | two counters that could never count, and one of them made the central claim unobservable |
| [`I.24`](register/FINDINGS_ABOUT_THE_WORK.md#i24-the-island-advertised-once-at-the-wrong-moment-and-could-never-be-raided) | the island advertised once, at the wrong moment, and could never be raided |
| [`I.23`](register/FINDINGS_ABOUT_THE_WORK.md#i23-a-rung-that-measured-nothing-and-only-known-controllers-could-say-so) | a rung that measured nothing, and only known controllers could say so |
| [`I.22`](register/FINDINGS_ABOUT_THE_WORK.md#i22-the-exam-was-one-of-the-things-the-islands-were-breeding-against) | the exam was one of the things the islands were breeding against |
| [`I.21`](register/FINDINGS_ABOUT_THE_WORK.md#i21-it-was-never-a-lineage-and-the-module-written-to-make-it-one-had-never-once-worked) | it was never a lineage, and the module written to make it one had never once worked |
| [`I.20`](register/FINDINGS_ABOUT_THE_WORK.md#i20-the-shape-of-the-archipelago-was-a-function-of-random-identity-bits) | the shape of the archipelago was a function of random identity bits |
| [`I.19`](register/FINDINGS_ABOUT_THE_WORK.md#i19-two-comments-described-two-designs-and-the-stale-one-owned-the-number) | two comments described two designs, and the stale one owned the number |
| [`I.18`](register/FINDINGS_ABOUT_THE_WORK.md#i18-one-refused-raid-wrote-18-mb-into-the-log) | one refused raid wrote 18 MB into the log |
| [`I.17`](register/FINDINGS_ABOUT_THE_WORK.md#i17-the-data-was-on-the-wire-the-code-was-deployed-and-nothing-said-tower) | the data was on the wire, the code was deployed, and nothing said tower |
| [`I.16`](register/FINDINGS_ABOUT_THE_WORK.md#i16-three-green-checks-and-a-release-that-would-not-assemble) | three green checks and a release that would not assemble |
| [`I.15`](register/FINDINGS_ABOUT_THE_WORK.md#i15-the-same-guard-probe-rotted-twice-and-then-found-the-wrong-copy) | the same guard probe rotted twice, and then found the wrong copy |
| [`I.14`](register/FINDINGS_ABOUT_THE_WORK.md#i14-a-whole-subsystem-was-built-tested-and-connected-to-nothing) | a whole subsystem was built, tested, and connected to nothing |
| [`I.13`](register/FINDINGS_ABOUT_THE_WORK.md#i13-one-dead-subscription-bred-three-and-five-symptoms-had-one-cause) | one dead subscription bred three, and five symptoms had one cause |
| [`I.12`](register/FINDINGS_ABOUT_THE_WORK.md#i12-the-engine-fingerprint-was-not-the-same-on-two-identical-machines) | the engine fingerprint was not the same on two identical machines |
| [`I.11`](register/FINDINGS_ABOUT_THE_WORK.md#i11-the-island-stopped-stayed-healthy-and-nothing-said-so) | the island stopped, stayed healthy, and nothing said so |
| [`I.10`](register/FINDINGS_ABOUT_THE_WORK.md#i10-a-probe-rotted-when-an-export-list-grew-and-only-the-compile-check-noticed) | a probe rotted when an export list grew, and only the compile check noticed |
| [`I.9`](register/FINDINGS_ABOUT_THE_WORK.md#i9-a-file-written-into-a-directory-that-does-not-exist-leaves-everything-green) | a file written into a directory that does not exist leaves everything green |
| [`I.8`](register/FINDINGS_ABOUT_THE_WORK.md#i8-a-probe-measured-the-wrong-quantity-three-times-and-never-once-crashed) | a probe measured the wrong quantity three times and never once crashed |
| [`I.7`](register/FINDINGS_ABOUT_THE_WORK.md#i7-a-parameter-that-is-ignored-makes-a-type-checker-useless-by-degrees) | a parameter that is ignored makes a type checker useless by degrees |
| [`I.6`](register/FINDINGS_ABOUT_THE_WORK.md#i6-a-constant-folded-call-is-not-a-call-and-a-probe-with-a-literal-proves-nothing) | a constant-folded call is not a call, and a probe with a literal proves nothing |
| [`I.5`](register/FINDINGS_ABOUT_THE_WORK.md#i5-a-closed-dispatch-with-a-catch-all-is-a-silent-fallback) | a closed dispatch with a catch-all is a silent fallback |
| [`I.4`](register/FINDINGS_ABOUT_THE_WORK.md#i4-a-copied-comment-was-false-in-the-commit-that-copied-it) | a copied comment was false in the commit that copied it |
| [`I.3`](register/FINDINGS_ABOUT_THE_WORK.md#i3-a-restore-that-refreshes-one-build-profile-leaves-the-other-perturbed) | a restore that refreshes one build profile leaves the other perturbed |
| [`I.2`](register/FINDINGS_ABOUT_THE_WORK.md#i2-an-inherited-scope-decision-was-carried-a-day-too-long) | an inherited scope decision was carried a day too long |
| [`I.1`](register/FINDINGS_ABOUT_THE_WORK.md#i1-a-docstring-that-calls-itself-a-skeleton-was-read-after-it-was-cited) | a docstring that calls itself a skeleton was read after it was cited |

### `D` — findings about the world

In [`register/FINDINGS_ABOUT_THE_WORLD.md`](register/FINDINGS_ABOUT_THE_WORLD.md), newest first.

| | |
|---|---|
| [`D.16`](register/FINDINGS_ABOUT_THE_WORLD.md#d16-the-fleet-solved-the-frozen-exam-in-about-a-day-once-it-could-keep-a-lineage) | the fleet solved the frozen exam in about a day, once it could keep a lineage |
| [`D.15`](register/FINDINGS_ABOUT_THE_WORLD.md#d15-the-frozen-exam-swings-by-a-hundred-points-in-a-day-on-a-bred-champion) | the frozen exam swings by a hundred points in a day, on a bred champion |
| [`D.14`](register/FINDINGS_ABOUT_THE_WORLD.md#d14-the-gun-is-fired-constantly-and-appears-never-to-hit) | the gun is fired constantly and appears never to hit |
| [`D.13`](register/FINDINGS_ABOUT_THE_WORLD.md#d13-the-network-is-never-silent-so-the-threshold-decides-nothing) | the network is never silent, so the threshold decides nothing |
| [`D.12`](register/FINDINGS_ABOUT_THE_WORLD.md#d12-height-buys-silence-and-the-picture-said-the-opposite) | height buys silence, and the picture said the opposite |
| [`D.11`](register/FINDINGS_ABOUT_THE_WORLD.md#d11-the-lamarckian-arm-was-designed-against-a-capability-faber-does-not-have) | the Lamarckian arm was designed against a capability faber does not have |
| [`D.10`](register/FINDINGS_ABOUT_THE_WORLD.md#d10-no-setting-of-the-interceptor-is-both-viable-and-playable) | no setting of the interceptor is both viable and playable |
| [`D.9`](register/FINDINGS_ABOUT_THE_WORLD.md#d9-turn-radius-is-the-wrong-quantity-for-a-turning-fight) | turn radius is the wrong quantity for a turning fight |
| [`D.8`](register/FINDINGS_ABOUT_THE_WORLD.md#d8-a-seeker-that-never-loses-lock-is-not-a-seeker) | a seeker that never loses lock is not a seeker |
| [`D.7`](register/FINDINGS_ABOUT_THE_WORLD.md#d7-breeding-works-and-the-frozen-ladder-is-beaten-inside-120-rounds) | breeding works, and the frozen ladder is beaten inside 120 rounds |
| [`D.6`](register/FINDINGS_ABOUT_THE_WORLD.md#d6-the-guided-interceptor-dominates-and-it-has-now-flattened-two-instruments) | the guided interceptor dominates, and it has now flattened two instruments |
| [`D.5`](register/FINDINGS_ABOUT_THE_WORLD.md#d5-the-genome-did-not-specify-the-controller) | the genome did not specify the controller |
| [`D.4`](register/FINDINGS_ABOUT_THE_WORLD.md#d4-the-first-ladder-did-not-grade-and-its-order-was-guessed-wrong) | the first ladder did not grade, and its order was guessed wrong |
| [`D.3`](register/FINDINGS_ABOUT_THE_WORLD.md#d3-a-speed-gate-on-an-exit-can-be-reached-by-crashing-into-it) | a speed gate on an exit can be reached by crashing into it |
| [`D.2`](register/FINDINGS_ABOUT_THE_WORLD.md#d2-the-model-settles-on-the-analytic-terminal-velocity-exactly) | the model settles on the analytic terminal velocity exactly |
| [`D.1`](register/FINDINGS_ABOUT_THE_WORLD.md#d1-the-arenas-walls-kill-a-drone-flying-flat-out-and-that-is-the-physics) | the arena's walls kill a drone flying flat out, and that is the physics |

