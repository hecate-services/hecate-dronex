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

## When this file splits

One file until it passes about 800 lines, then one file per series under
`register/`, with this file becoming the index.

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

---

# D: findings about the world

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

## I.1: a docstring that calls itself a skeleton was read after it was cited

Deciding what to keep from the counter-UAS line, I wrote that its correlation
logic was "genuinely the algorithm you want" and worth porting as a pure
function. Then I opened it.

`on_contact_observed_correlate_track` says of itself, in its first paragraph:
*"Correlation here is the SKELETON minimum: one confirmed track per drone id,
single-sensor passthrough."* The body confirms it: `TrackId = <<"track-",
DroneId/binary>>`. **The correlation is string concatenation on the drone's
own self-reported identity.** There is no association by predicted position, no
gate, no evidence accumulation and no track-lost. It works because Remote-ID
hands you the identity, and it is meaningless for any sensor that does not.
`maybe_confirm_track` beside it is a one-shot idempotence guard, not an
accumulator.

**Cost:** nothing, because it was caught inside one turn. **What it would have
cost:** an item in the order of work sized as a port that was actually a design,
discovered at implementation time.

This is the third instance of one pattern, after the two in `INHERITED-7`.
Notably the file **announced its own status in the place a reader would look
first**, so this was not even a case of having to read code. It was a case of
citing a module without opening it.

**The rule, sharpened:** before writing that an existing thing can be reused,
open it and quote the line that says so. If the quote cannot be produced, the
claim is not yet made.

**ELI5.** Someone said the old kitchen had a bread oven worth keeping, without
going in. Inside there was a hand-written sign on it reading "this is not really
an oven, it is a box with a light bulb in it". The sign had been there the whole
time, on the front, at eye height. The lesson is not about ovens. It is that
saying you can reuse a thing means walking over and looking at it.

## I.4: a copied comment was false in the commit that copied it

`.github/workflows/lint.yml` was taken from a sibling, comment and all. It said
the job runs on the glibc erlang image *where macula resolves a prebuilt QUIC NIF
and no Rust toolchain is needed*. True there. **False here, in the same commit,
because that commit also added `faber_tweann`**, which has no prebuilt artifact
and always builds `native/faber_nn_nifs` from source.

CI said so immediately: `ERROR: Rust toolchain not found. ===> Hook for compile
failed!` The image build passed in the same run, because the `Containerfile`
installs rustup, so the failure was visible only in the job whose comment denied
it could happen.

**What makes this worth an entry rather than a shrug.** Copying a file from a
sibling copies its ASSERTIONS about the world, and those assertions were true of
a different dependency list. The comment was not stale in the sense of having
aged; it was wrong on arrival, and the thing that made it wrong was three lines
away in the same commit.

The library offers `FABER_TWEANN_SKIP_NIF=1` and a pure-Erlang fallback, and
taking it would have made CI pass without building the NIF. That was refused: the
whole reason the dependency sits at the spine is to find NIF build problems
early, and a CI that skips the NIF tests something the image does not ship.

**ELI5.** They copied a checklist from the workshop next door. One line said "no
need to bring a ladder, the shelves here are low". They copied it on the same day
they installed a tall cupboard. The line was not out of date. It was wrong the
moment it was written, and the thing that made it wrong was in the same box of
tools they carried in.

## I.3: a restore that refreshes one build profile leaves the other perturbed

`scripts/prove_the_guards_bite.sh` breaks a boundary, compiles, runs the suite,
asserts red, and restores. It reported **all six guards biting**. The next plain
`rebar3 eunit` then failed **four** tests, against sources that `git diff` showed
were already correct and that `grep` confirmed line by line.

The restore was not the problem, and neither was the mtime, which the script
already handled. **`rebar3 compile` builds the `default` profile and `rebar3
eunit` builds the `test` profile, and they hold separate beams.** The script
compiled in one and tested in the other, so refreshing `_build/default` left
`_build/test` holding every perturbation. `rm -rf _build/test` on restore fixes
it.

The known trap, `INHERITED-3`, says a restore leaves an older mtime and rebar3
serves a stale beam. That was guarded. **The trap had a second dimension nobody
had written down**, and guarding the recorded half is what made the failure
surprising rather than expected.

Two smaller ones, both caught by the script's own compile check rather than by
reading its output as a result, and both instances of *a perturbation that only
breaks the compile is not a red check*:

- an unexported function nobody calls is an unused-function warning, and this
  tree builds `warnings_as_errors`
- a function definition placed among the attributes puts `-export_type` and
  `-record` after the first function, which Erlang rejects outright

**ELI5.** They tested the fire alarm by lighting a small fire in the kitchen,
confirmed it went off, put the fire out, and wrote down that the alarm works.
What they had not noticed is that the building has two kitchens with the same
layout, and they had been lighting fires in one and cleaning up in the other. The
fire was still burning next door. Nothing was wrong with the alarm or with the
cleaning up. There was just a second room nobody had put on the list.

## I.2: an inherited scope decision was carried a day too long

The counter-UAS line was written up as a deferred second act: contracts kept,
nothing exercised. Raf's proposal to make it the island's **static defence
network** is better for a reason already written into this repository's own
charter, rule 4: *a capacity that was never exercised is not evidence of
anything.*

The deferral had been inherited from the framing of the previous session rather
than argued fresh. It survived a whole design pass because it looked settled.
Two things fell out of reversing it within the day: the fight stops being
symmetric, which is the shape P7 found sterile, and the sensor-model behaviour
becomes load-bearing instead of shelved.

**ELI5.** They decided to keep an old workshop locked up in case it was useful
later, wrote that down, and then everything after that treated it as decided.
The better answer was to open it and use half of it now. What made the mistake
last a day was not that it was hard to see. It was that it had already been
written down once, and written down looks like decided.
