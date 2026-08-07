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

## I.20: the shape of the archipelago was a function of random identity bits

Five islands, every admission filter passing for every pair — all four held all
three neighbours' leases, every engine fingerprint identical, every roster above
the floor — and the graph that actually ran was four near-fixed edges. `beam03`
was raided **three** times where the two most-attacked islands were raided about
four hundred and eighty. It held a full roster because it never paid for a
defence, and topped the exhibit's leaderboard at 100% while being, in effect, not
in the archipelago at all.

The selector was two lines:

```erlang
target(Heard, Self) -> chosen([H || H <- Heard, H =/= Self]).
chosen(Others)      -> {ok, hd(Others)}.
```

`Heard` is built from `maps:to_list(open_islands)`. **A map of 32 keys or fewer
is a flatmap, and a flatmap yields its keys in sorted term order.** So `hd/1` did
not mean "any of them". It meant "whichever island minted the lowest id", for
ever. `beam03`'s `e649…` sorted last for all three of its neighbours, so it was
everybody's third choice and was reached only in the rare window where two
higher-sorted leases were simultaneously stale.

Three things made it survive:

- **Every filter was working.** `targets/1` checks lease freshness, engine
  fingerprint and roster floor, and all three passed. The failure was one
  function later, in the part nobody thought was a decision.
- **The symptom read as a different bug.** An island that raids happily and is
  never raided back is the exact signature of `I.11`, an advertisement that never
  landed. The first hour went into the advert.
- **It looked like a result.** An island with a perfect exam score and a full
  roster reads as the best island on the board, not as one that is being left
  alone.

Fixed by drawing from the admitted candidates, threading the island's own
generator per `D.5` — whom an island chose to attack is part of the run, and a
run must stay a pure function of its seed.

**ELI5.** A group of neighbours each had a list of who was free to play, and each
one always picked the first name on their list. Nobody noticed the lists were
alphabetical, so the child whose name came last never got picked, by anyone, ever.
Everyone's rule was fair. The order they were reading was not, and nobody had
chosen that order — it came from how the paper happened to be sorted.

## I.19: two comments described two designs, and the stale one owned the number

The raid handshake used a 120-second timeout. `dronex_mesh` explained it: *"a
long timeout, because the callee is fighting — the defender validates every
genome, then runs a whole engagement of up to 1200 ticks before it can answer."*

That was true once. It had stopped being true months earlier, when the protocol
was split so the defender answers **before a single tick is simulated** and
spawns the fight. `island_server` says exactly that, in a comment written at the
time. And `dronex_raid` even recorded the consequence: *"the timeout can go back
to being a real one."*

Nobody moved the number. So the repository contained two comments describing two
different designs, and the stale one was attached to the constant that actually
ran. A target whose route was dead cost the attacker two minutes of a blocked
process per attempt, every two minutes, all day.

The general shape: a comment justifying a value lives next to the value, and a
comment recording a design change lives next to the change. When those are in
different files, the change can land completely and correctly while the value it
invalidated sits untouched behind a justification that no longer describes
anything.

**ELI5.** A sign on a machine said "wait twenty minutes, the oven is still
heating". Someone later replaced the oven with one that is instant, wrote that
down on the new oven, and left the old sign up. Everyone kept waiting twenty
minutes. Both notes were honest when written. Only one of them was next to the
knob.

## I.18: one refused raid wrote 18 MB into the log

Every raid failure was logged with `~p` on the reason. The reason from a lost
call carries the arguments, and the argument is a raid request: twelve packed
genomes. One refusal was about **34,000 lines and 18 MB**. Twelve hours produced
a 5.9-million-line log whose only human-readable content was 175 warnings that no
`grep` could reach in reasonable time.

The cost was not disk. It was that diagnosing `I.20` above meant working around
this log first, and the failure it was hiding was in the same subsystem that
produced it.

Bounded with `~P` at a depth, which bounds **any** shape — the interesting
failures are the ones whose shape nobody predicted. And the message now names the
target, which it did not: the who-fails-to-call-whom matrix had to be
reconstructed from procedure names inside a binary dump.

**ELI5.** Every time a delivery failed, the driver wrote down the reason and also
photocopied the entire contents of the van. After a day the filing cabinet held
nothing but van inventories, and the one useful sentence was somewhere inside
them.

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

## I.17: the data was on the wire, the code was deployed, and nothing said tower

Asked to visualise the defending island's sensor stations, the work shipped and
was reported as done. Raf's reply was that no towers were shown.

Everything checked out. The islands published `ground` and `ground_range`; the
live page carried them in `data-bout`; the deployed JS bundle contained `towers()`
and `coverage()`; the caption rendered "5 of them"; and the projection put all
five masts in the middle of the canvas at a readable size. Every link in the
chain verified, and the answer to the question was still **no**.

The masts were drawn as a thin vertical line with a dot on top. That is
**exactly the mark the same canvas already uses for a drone**, which is joined to
its ground position by a stalk so that altitude reads. Five towers stood among
twenty-four aircraft using the aircraft's own vocabulary, and the coverage rings
were drawn in the defender's red, so they read as stray flight paths. Nothing was
missing and nothing was broken. It simply did not communicate.

Two things this changes.

**Verifying the data path is not verifying the picture.** The checks run were all
of the form "did the value arrive", and a value can arrive and mean nothing. The
fix was to render the live payload offline with the deployed projection constants
and LOOK AT IT — which took one script and answered in one image what four
verified links could not.

**Silhouette before colour.** A recolour would not have fixed this. What a viewer
reads first is shape, and while a tower had a drone's shape it was a drone in
another colour. It is now a splayed lattice mast with cross-braces, a base pad
and a sensor head, and coverage is a faint filled disc rather than an outline, so
watched ground reads as an area and the dark between the discs reads as the way
in.

This is the second time on this track that something was drawn correctly and
could not be seen — the earlier one was a drone's ground shadow painted black on
a near-black floor. Both passed every check that did not involve looking.

**ELI5.** Someone was asked to put signposts along a path, and they did. Then
they checked that the signs had been made, that the right words were painted on
them, that they had been delivered, and that they were standing in the right
places. All true. But the signs were the same shape and colour as the trees, so
everyone walking past saw trees. The only check that would have caught it was
walking the path and looking.

## I.16: three green checks and a release that would not assemble

`sensor` is a module in `faber_tweann`, which is a dependency. The BEAM has one
flat module namespace, so `sensor` in this tree and `sensor` in that one are the
same name, and `rebar3 release` refuses to assemble with:

    Duplicated modules: sensor specified in faber_tweann and hecate_dronex

Nothing local objected. `rebar3 compile` was clean, 337 tests passed, Dialyzer
was clean, elvis was clean, and twenty-three guard probes bit. **Every one of
those runs the application, and none of them builds the release.** The failure
appeared eight minutes after the push, in CI, at the one step nobody runs by
hand.

The rule that follows is small: **`rebar3 as prod release` is part of the local
check, not part of CI's job.** It is the only command in this repository that has
an opinion about the global namespace.

The naming lesson is the larger half. `sensor`, `network` and `tracks` are all
names that describe a *kind of thing* rather than a *thing this repository does*,
and in a flat namespace shared with every dependency that is a collision waiting
for a dependency to be added. Only `sensor` collided; all three were renamed
`ground_sensor`, `ground_network`, `ground_tracks`, which is a better answer on
its own terms — `ground_sensor` says what distinguishes it from `drone_senses`,
which `sensor` never did. Screaming architecture is usually argued as a
navigation property. Here it is also a correctness one.

**ELI5.** Everyone in a small village is on first-name terms, and someone called
their new baby by a name a neighbour's child already had. Inside the house it was
never a problem: the family always knew which child they meant. It only broke
when the whole village was called together and two children answered to the same
name. The fix was to use a fuller name that also happens to say something about
who the child is.

## I.14: a whole subsystem was built, tested, and connected to nothing

`sensor`, `tracks` and `network` were written, compiled, and covered by their own
passing unit tests. Every fight in the system ran without any of them. The static
defence — the entire point of item 8 — was dead code with a green suite behind
it, and the suite was green **because** the tests supplied the network themselves.
A test that hands a module its input cannot notice that nothing in production
ever does.

It was caught by a one-line grep for `network:home` returning no matches outside
the module that defines it. Nothing else in the toolchain had an opinion:
Dialyzer was clean, elvis was clean, 285 tests passed, and the compiler is
perfectly happy with an exported function nobody calls.

The lesson generalises past this instance and is now the shape of three
assertions: **the wiring is a boundary and needs its own guard.** For a pure
value that flows through a system, the guard is that the value reaches the far
end — `the_ground_reaches_the_result_test` runs an engagement two ways and
asserts the results differ.

This is I.9 wearing different clothes. There, `radio.erl` was written into a
directory that did not exist and everything downstream compiled *because* the
module was absent. Here the module was present and reachable and called by
nobody. Both are the same question asked twice: **is this code actually on the
path?** — and neither the compiler nor a unit test is the thing that answers it.

**ELI5.** Someone built a smoke detector, tested it in the workshop by blowing
smoke at it, and it beeped every time. Then they wrote in the log that the house
had a smoke detector. It was still in the workshop. Nobody had put it on a
ceiling. Every test of it was honest, and every one of them was a test of the
detector rather than a test of the house.

## I.15: the same guard probe rotted twice, and then found the wrong copy

Three failures of one mechanism, in one sitting.

**It rotted.** A probe proving the ablation's mute reaches the drones quoted the
whole of `engagement:ask/5` verbatim. Item 8 added a network argument, the
pattern stopped matching, and the probe reported "changed nothing" instead of
biting. This is I.10 exactly: a probe anchored on something large enough that
ordinary work moves it. Re-anchored on `muted/3`, four short lines whose whole
job is the thing being proved.

**It found the wrong copy.** A probe that the defender fights at home searched
`island_server.erl` for `network:home()`. Perturbing the raid path left the
probe green, because the same string appears on the training-bout path a few
hundred lines away. **A textual probe cannot tell two occurrences apart.** The
fix was not a better regex: hosting a raid moved into `defence:host/1`, where it
belonged anyway, and the assertion now calls the function.

**It proved a state that could not occur.** A probe that the network stays silent
until a track is confirmed passed against a test using a network that had
observed nothing at all — no tracks, confirmed or otherwise, so both the correct
and the broken code said nothing. The test had to construct a network holding a
*tentative* track and no more, which turned out to need a **single** station:
five stations agree in one tick and clear the threshold before a second tick
happens. Writing that test surfaced a genuine property of the design that had
not been noticed — agreement across stations is itself the evidence, and it is
why a ghost, invented independently by each station at its own position, does not
confirm.

**ELI5.** Three ways of checking a lock without checking the lock. First they
described the door so precisely that repainting it meant the description no
longer matched anything, and they wrote down "nothing to check" instead of
"something is wrong". Then they went looking for a door by its colour, found a
different door of the same colour on the far side of the building, and rattled
that one. Then they tested whether a door stays shut when it is locked, on a
doorway that had no door in it at all: it stayed shut either way.

## I.13: one dead subscription bred three, and five symptoms had one cause

An island's mailbox reached **615,722 messages**. It was wedged inside
`macula_client:subscribe` making the problem worse, `snapshot` calls timed out at
thirty seconds, twenty-six publishes had failed, and the public page showed a
growing pile of raids stuck `in flight`.

Five symptoms, one line.

`listen_for_neighbours/0` subscribed to all three inter-island topics, and a
single `listening` boolean recorded that it had. `{macula_event_gone, Ref, _}`
for **any one** of them set that boolean false and re-ran the lot — so one dead
subscription produced three new ones while its two live siblings stayed live.
The next death produced three more. Every fact then arrived once per surviving
subscription, and the growth is what filled the mailbox.

⚠ **The comment directly above it already knew.** It said, in as many words, that
every `subscribe` returns a fresh reference and the pool keeps them all, so
re-subscribing on a timer would multiply deliveries. It guarded the TIMER and
left the death path to do exactly what it had just described.

⚠⚠ **And the symptoms pointed everywhere but at the cause.** Raids stuck in
flight looked like a raid-protocol fault; the failed publishes looked like a mesh
fault; the timing-out snapshot looked like the island being busy. The mailbox
depth was the only number that named the real thing, and nothing published it.

**What changed.** Subscriptions are tracked per topic, `{macula_event_gone, Ref}`
drops exactly that reference, and `listening/1` fills only the gaps. `listening`
on the wire is now DERIVED — true when every topic an island needs is
subscribed — because a boolean beside the subscriptions is a second copy of the
truth that can disagree with it, which is precisely what happened.

**ELI5.** A shop had three phone lines. When one of them was cut, someone
reconnected all three — so now there were five, then seven. Every caller got
through to every line at once and the shop drowned in its own ringing. The
instruction card by the phone already warned that connecting a line twice doubles
the calls. It was written for a different situation and nobody applied it to this
one.

## I.12: the engine fingerprint was not the same on two identical machines

Two islands, same image, same OTP, same architecture. Neither ever attempted a
raid against the other. `raids` stayed at **zero** on both for ten minutes while
`open_islands` showed each of them had heard the other perfectly well.

**They were filtering each other out as incompatible engines.** The fingerprint
is checked before a raid is sent, precisely so that two different builds cannot
produce a result comparable to nothing — and it was different on two builds that
were identical.

⚠ **`term_to_binary/1` does not encode a map canonically.** For a map large
enough to be a hashmap — `airspace:limits/0` has about thirty-five keys — the
entries are emitted in internal hash order, and for ATOM keys that order depends
on the node's atom table, which depends on the order atoms were first created.
Measured on the two live islands, hashing each part separately:

| part | beam01 | beam02 |
|---|---|---|
| otp, erts, arch, topology, genes, senses, comms | identical | identical |
| **physics, `term_to_binary/1`** | `AB9CD351` | `8BF316FD` |
| **physics, `term_to_binary/2` `[deterministic]`** | `41BF0006` | `41BF0006` |

⚠⚠ **It fails in the direction that looks like caution.** A fingerprint exists to
refuse mismatched engines. One that is wrong refuses *everything*, and a
mechanism refusing everything reads as a check working rather than as a check
being broken. Nothing errored, nothing logged, `/health` was green, both islands
were open and advertising, and the entire raid protocol simply did not run.

**Why the obvious local test would not have caught it.** Two equal maps built in
different orders inside ONE node serialise identically, so a same-node property
test passes with or without the flag. The divergence needs two atom tables. What
is asserted instead is the encoding itself — that `fingerprint/0` equals the
`[deterministic]` hash — plus that the two encodings genuinely differ, so the
assertion has something to catch. Both go red when the flag is dropped.

**ELI5.** Two machines were told to describe the same room and compare notes, to
be sure they were talking about the same room before doing anything together.
They listed the same furniture, but each wrote the list in its own order, so the
notes never matched and neither would proceed. They stood there politely
refusing each other, and from outside it looked exactly like the check doing its
job.

## I.11: the island advertised once, at the wrong moment, and could never be raided

Two islands, twelve raids launched, **one** ever hosted. The rest died at the
caller with `vanished into the dark: timeout` after two minutes, while the
callee's `defences` counter never moved.

**The cause was one line in `init/1`.** `advertise_self()` ran once at boot,
before `hecate_om_identity` could answer, so `dronex_mesh:advertise/2` failed on
the fleet realm and returned an error nobody read. `macula_client:advertise`
was therefore never reached, the pool's `procs` map stayed empty for the life of
the process, and inbound CALLs had no handler to dispatch to.

⚠ **The comment above that line said "the retry is the next timer tick".** There
was no such tick. Asserting a safety net in prose is worse than not having one,
because the next reader stops looking for it.

⚠⚠ **It was invisible from every angle, and the asymmetry is why.**

| what it did | why it kept working |
|---|---|
| bred, benchmarked, ablated | none of it touches the mesh |
| published vitals, bouts, raids | the PUBLIC realm comes from an environment variable |
| **heard its neighbours** | `subscribe` also uses the public realm, so it never asks `hecate_om` for anything |
| **raided them** | outbound calls need no advertisement of its own |
| answered `/health` green | it was perfectly healthy |

So it heard everyone, attacked everyone, and could not be attacked back. The
only symptom anywhere was a counter on a *different machine* failing to rise.

⚠⚠⚠ **And the station kept a route to it.** `macula_remote_advertise_registry`
on Stockholm still held both islands' procedures, with `conn_pid`s that were
alive, from an earlier incarnation. So a CALL was accepted and forwarded rather
than refused: the caller got silence instead of `unknown_next_peer`, which is the
difference between waiting two minutes and failing in 27 milliseconds. A probe
against a procedure that had NEVER existed came back correctly in 27 ms; the
probe against the real one hung. That contrast is what located it.

**What changed.** A `mesh_check` timer re-asserts the advertisement every minute
— not once-until-it-works, because a pool restart, a link respawn and a stale
station entry all heal the same way and none of them announces itself.
Re-subscribing is NOT re-asserted on the timer, because every `subscribe` returns
a fresh reference and the pool keeps them all, so a minute-by-minute re-subscribe
would multiply deliveries; that re-arms on `macula_event_gone` instead. And
`advertising` and `listening` now go out on every vitals fact, so the state
"healthy, busy, and unreachable" is one field rather than a six-step dive.

**ELI5.** A shop put its phone number in the directory once, on the morning it
opened, at a moment when the phone company was not yet listening. Nobody noticed,
because the shop could still ring everybody else, and did. The directory even
still had an old number from the previous owner, so callers heard ringing rather
than "no such number", and gave up after two minutes assuming nobody was in. The
shop's own sign said OPEN the entire time.

## I.9: a file written into a directory that does not exist leaves everything green

`radio.erl` was written into `src/speak_between_drones/`. The directory had never
been created, the write failed with `no such file or directory`, and the next
`rebar3 compile` was **clean** — because the module was absent, nothing referred
to it yet, and the failure scrolled past in a batch of output that ended in four
green lines.

⚠ **The dangerous part is what would have happened next.** The ablation is an
instrument whose whole output is a delta, and a delta of zero from a mute that
reaches nothing is indistinguishable from a delta of zero from a channel nobody
depends on. One is a broken instrument and the other is a finding, and the report
would have printed the finding.

**What it changed.** Three probes were added to
`scripts/prove_the_guards_bite.sh`: the radio's horizon, the mute reaching the
drones, and the two sides muting independently. Each is verified to compile and
then verified to turn a suite red, so a disconnected instrument now fails loudly
instead of reporting confidently.

**ELI5.** Somebody built a thermometer, forgot to attach the sensor, and the
display still read a perfectly reasonable twenty degrees. Nothing looked broken.
The room could have been on fire.

## I.10: a probe rotted when an export list grew, and only the compile check noticed

The `a module reaches into mnesia` probe worked by naming `island.erl`'s export
list verbatim and adding one entry to it, then appending a function that used
mnesia. Item 5 added `roster_of/1` to that line. The export edit silently stopped
matching; the appended function still landed; an unexported function nobody calls
is an unused-function warning, and this tree builds with `warnings_as_errors`.

So a probe that had been biting for weeks became a probe that did not compile,
and nothing announced it. It was reported as `SKIPPED` — which the script counts
as a failure precisely because of INHERITED-3 — the first time the guards were run
after item 5.

⚠ **This is the fifth firing of the same trap in this one file**, and the first
where the perturbation rotted rather than being written wrong. The rule the file
already carried was *leave the call graph intact*. The rule it gains is narrower:
**anchor a perturbation on text that has no reason to grow.** It is anchored on
`-export_type([island/0]).` now, a line with one entry, rather than on a list that
gains a name every time the module gains a capability.

**ELI5.** The fire alarm was tested by pressing a button, and the button was
described as "third from the left". Somebody added a switch to the panel. The
instructions still said third from the left, so the test went on being performed,
on the wrong switch, and the report kept saying the test was done.

## I.11: the island stopped, stayed healthy, and nothing said so

Twenty minutes after the first deploy, the island on beam02 had stopped. Not
crashed — stopped. Its clock was not advancing, it had published nothing, and
every `gen_server:call` into it timed out at five seconds and then at thirty.

`/health` answered `ok` throughout. `docker ps` said `healthy`. `docker stats`
said 0.55% CPU. The station link was up and the process was `running`.

**The chain, in the order it was actually unpicked.**

| | what was seen | what it meant |
|---|---|---|
| 1 | calls time out | read as a wedged process; it was a busy one |
| 2 | `current_function` = `timer:sleep`, reductions flat | not busy either — *waiting* |
| 3 | `current_stacktrace` | `island_server:handle_info/2` → `roster_log:append/3` → `reckon_gater_retry:do_retry/4` |
| 4 | container log | `{invalid_stream_id, <<"roster">>}`, `Retry attempt 8 … after 14621ms` |

The stream id was `roster`. `reckon_gater_stream_id` accepts exactly two shapes,
a user stream `<prefix>-<32 lowercase hex>` or a system stream `$<ns>:<name>`,
and a bare word is neither. It is now `$dronex:roster`.

⚠ **And the rejection did not fail like a validation error.**
`reckon_gater_retry` has an explicit non-retriable whitelist with
`{invalid_stream_id, _, _}` in it. But `reckon_db_stream_path:id_nodes/1`
**raises** `{invalid_stream_id, StreamId}` — a two-tuple, as an exit from the
gateway worker, not a returned error. The whitelist cannot match it, so a
permanent validation failure was retried eleven times with exponential backoff:
roughly four minutes of a process doing nothing but sleeping. **This is a defect
in reckon-db/reckon-gater and is not fixed here** — it only fires for a client
that passes an invalid id, which was our bug.

⚠⚠ **The stream id was ours. Blocking the island on a store write was the
design's, and the bad id merely found it.** `CLAUDE.md` has carried the rule the
whole time: DB I/O belongs to a dedicated worker and NEVER blocks the flow. The
snapshot handler called the store directly, on the island's own process, with
the clock, the trainer and the publisher all behind it in one mailbox.

**Three things changed.** `roster_log_writer` is now the only process allowed to
block on the store, and it **coalesces**: a snapshot is full state, so it drains
its mailbox and keeps the last, which makes a slow store cost staleness rather
than unbounded memory. `roster_writes`, `roster_write_failures` and
`roster_writes_dropped` go out on every vitals fact, because the one thing this
failure had no signal for was whether the lineage was being saved at all. And a
test asks reckon-gater's own validator whether the stream id is acceptable,
rather than restating its rule here.

**What did NOT catch it.** 233 green tests, a clean dialyzer, sixteen guard
probes, and a healthy container. Every test that touched persistence used a
store that was never there, so the write always failed fast and the blocking
path was never once executed.

**ELI5.** A machine was told to file its paperwork in a drawer whose label was
not a real label. Instead of saying so, the filing clerk kept trying the drawer,
waiting a little longer each time, for four minutes. The whole factory was
waiting behind that one clerk, and the light on the door still said OPEN.

---

# D: findings about the world

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

## I.8: a probe measured the wrong quantity three times and never once crashed

`can_a_drone_dodge_an_interceptor.escript` was written to answer one question and
gave three confident, wrong, uniform answers before it gave a right one.

| | what it reported | what was wrong |
|---|---|---|
| 1 | 0% hits at every range | it counted KILLS. One interceptor does half a drone's health, so a single launch can never kill and the answer was necessarily zero |
| 2 | 0% hits at every range | `element(12, D)` is `battery`, not `health`. A hand-counted record offset read 7,920,000 where it meant 10,000, so every comparison was false |
| 3 | 100% hits at every range | the evasion was the `evader` drill, which turns away ONCE and then runs straight, which keeps a target dead centre in a pursuer's seeker for the whole flight |

And the sweep script that consumed its output got it wrong twice more: once taking
the criterion THRESHOLDS for results, because each line carries two numbers; once
on Erlang printing `%%` as two literal percent signs, since `io:format` escapes
with `~` and not with `%`.

⚠ **Every one of those printed a plausible table and a confident verdict.** The
first two would have been read as "the design is wrong"; the third as "the design
is right and needs no work". None of them crashed, none looked odd, and the
verdict line was already written to be believed.

**What actually caught each one:** tracing a single engagement tick by tick, which
showed the interceptor hitting for 5000 damage while the probe reported a miss.
Not the summary. The trace.

**Two rules earned.** A hand-copied record offset is the trap the trainer already
hit and fixed with accessors; a script felt too small to bother and was not. And a
script that parses another script's prose is a mirror of its formatting, so the
producer now emits one machine-readable line and the consumer reads only that.

**ELI5.** Someone was asked to find out whether a goalkeeper can save a penalty.
First they counted only the shots that broke the net, and reported that no shot
ever gets past. Then they read the wrong column of the scoresheet and reported it
again. Then they tested it with a goalkeeper who runs away from the ball, and
reported that no penalty is ever saved. Every report was neat, confident and
wrong, and nothing went visibly wrong at any point.

## I.7: a parameter that is ignored makes a type checker useless by degrees

`breed:random/2` took a generator and a second argument it never read, declared
`pos_integer()`, and every caller passed `0`.

At runtime that is harmless. To dialyzer it is a call that cannot return, so the
recursive clause of `trainer:seed_roster/3` became unreachable, its success
typing collapsed to `(_, 0, _)`, and a helper beside it was reported as never
called. **Four warnings, none of them about the actual defect**, and all of them
about code that works.

The cost was small because dialyzer runs on every commit here. The cost of NOT
running it would have been a contract that lies, in a module whose whole job is
to be the one place randomness is honest about itself.

**ELI5.** A form had a box on it that nobody ever filled in, and the instructions
said the box must contain a positive number. Everyone wrote zero, and everything
worked, because no human ever read that box. Then they bought a machine to check
the forms, and it refused to process anything after that line, and reported four
problems with the parts that were fine.

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

## I.5: a closed dispatch with a catch-all is a silent fallback

`network_evaluator` takes an `activation` atom, and a design document here said
adding a deterministic table activation was "one function", because it
"dispatches through `functions`".

It does not. It dispatches through a **private** `apply_activation/2` whose
clause list is closed and whose last clause is:

```erlang
apply_activation(X, _) ->
    math:tanh(X).
```

So passing `tanh_table` is not an error. It **silently becomes libm tanh**, the
network looks like it worked, and every published fight is quietly
non-portable. That is insight 002's shape exactly: a silent fallback hides
correctness divergence, not just speed.

**The claim that made it dangerous was mine**, and it was made from the record
`activation :: atom()` rather than from the dispatcher, which is the same
directory-listing-as-survey habit as `INHERITED-7` and `I.1` in a third costume:
reading a type and inferring a mechanism.

Raf's decision was to keep the evaluator, with its CfC memory, plasticity and
NIF, and drop bit-identical replay across runtimes. `CHARTER.md`,
`DESIGN_THE_AIRSPACE.md` and `DESIGN_WHAT_WE_TAKE_FROM_FABER.md` were amended so
none of them still asserts exactness, and the three rejected alternatives are
recorded in case they come back.

**ELI5.** A machine had a dial for choosing which kind of blade to use. The
instructions implied you could add your own blade to the list. You cannot: the
list is fixed, and if you ask for a blade it does not have, it quietly fits the
default one and carries on. It does not stop, and it does not tell you. So you
would go home believing you had cut with your blade.

## I.6: a constant-folded call is not a call, and a probe with a literal proves nothing

The probe for *no libm on the match path* perturbed `fixed:clamp/3` to compute
`trunc(math:sqrt(1.0)) * 0` and add it to the result. It compiled, changed no
answer, and the structural guard **stayed green**, which looked like the guard
being broken.

The guard was right. `math:sqrt(1.0)` has a literal argument, so the compiler
evaluates it at compile time and no call survives into the beam's imports chunk.
There genuinely was no libm call at runtime to find.

`math:sqrt(abs(V) + 1.0)` cannot be folded, and the guard bites immediately.

**The general shape:** a test that reads what the compiler produced is testing
the compiler's output, not the source. That is exactly why it is the right check
for this property, and exactly why perturbing it needs care.

**ELI5.** They tested a metal detector by hiding a coin, but they hid it before
the floor was laid and it ended up under the concrete rather than in the room.
The detector did not beep. The detector was fine. There was nothing in the room.

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
