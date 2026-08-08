# Findings about the work

How the work itself went wrong. Every entry is a mistake that was paid for once, written down so it is not paid for twice.

⚠ **Every entry carries an ELI5 section. No exceptions.** `CHARTER.md` rule 10.
The index, and the rule itself, are in [`../REGISTER.md`](../REGISTER.md).

---

## I.25: two counters that could never count, and one of them made the central claim unobservable

Raf looked at the exhibit and asked whether it made sense. It did not, in two
places, and neither had ever been measured.

**`sorties` was always zero.** `raid:sortie/3` musters a party with
`roster:take/2`, which evicts it, and then called
`roster:count_sortie(RosterWithoutThem, Id)`. The lookup missed, the clause
returned the roster unchanged, and every increment since the raid protocol was
written was a silent no-op. Measured on beam03 on 2026-08-09, after **2,524
raids**: max sorties across all 71 entries was 0, and every champion this
archipelago has ever published carried `champion_sorties => 0`.

⚠ **The obvious repair was worse than the bug.** Counting before the take, or
writing the entry back after it, re-inserts a controller that is supposed to be
airborne — so an island would field the same genome at home and away at once and
the roster's finiteness, which is the entire price of a raid, would be
decorative. The count has to travel WITH the party, because `raid:settle/3`
re-admits the very record it was handed.

**A captured genome could never become champion.** `raid:absorb/3` admits a
foreign genome at `fitness => 0` deliberately — its old number was measured
against somebody else's opponents — and its comment says it "earns a local number
only if the local trainer ever sits it". The trainer sits it every time it is the
worst entry, computes a real score against the same opponents and starts as the
challenger, and **threw that number away**. So it stayed at 0 for ever.

`roster:best/1` orders on stored fitness. A permanent zero is permanently last,
so a captured genome could never sit the exam, never be published as the
champion, and never appear as a controller that crossed the mesh.

| beam03, 2026-08-09 | entries | fitness |
|---|---|---|
| bred | 52 | 10 to 30 |
| captured | 19 | **0 to 0** |

⚠⚠ **SO "0 OF 10 CROSSED THE MESH" WAS NEVER EVIDENCE ABOUT THE WORLD.** The
archipelago's one idea is that a raid moves opponent diversity across the mesh,
and the panel built to show it was reporting a number that could not have been
anything else. It had been read, in this session, as "no genome has crossed
yet" — a statement about the fleet — when it was a statement about the code.

**The fix is one line and costs nothing:** store the incumbent's score, which was
already being computed. It does not change the comparison, which is still on the
two numbers just measured; it changes who is the worst NEXT round, and a measured
number is strictly better than a stale zero for that.

**Both tests were written, then verified by putting the bugs back.** The first
version of the captured-fitness test passed with the bug still in, because its
assertions were `fitness >= 0` and "some entry has fitness above zero" — both
vacuously true. It now compares against the score the round actually reported,
and asserts that score is non-zero first, so a seed that happened to measure zero
fails loudly instead of passing for the wrong reason.

**ELI5.** A club kept two records about its players: how many away matches each
had played, and how good the players it signed from other clubs were. Nobody had
checked either. The away counter was written into the locker of a player who had
already left for the coach, so it always read zero. And a signed player was
entered on the books as "worth nothing" until somebody assessed them, which the
club's own rules said would happen at the next trial — except the trial results
were thrown out every time. So a signed player was worth nothing for ever, could
never be picked for the first team, and the club's noticeboard proudly reported
that not one of its signings had ever made the team. That was not a fact about
the signings.

## I.24: the island advertised once, at the wrong moment, and could never be raided

> ⚠ **RENUMBERED FROM `I.11` ON 2026-08-08.** Two different findings carried that number: this one and the island that stopped while reporting healthy. Three citations across the repository pointed at an ambiguous target. The older entry keeps `I.11`, because renumbering it would have invalidated citations that were correct when they were written.

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

## I.23: a rung that measured nothing, and only known controllers could say so

The held-out ladder was written with six rungs and shipped with six rungs, and
they are not the same six.

`hunter` closed and shot exactly as `bruiser` does, and additionally **came
looking** when its target left the 120 degree cone. Every rung of the curriculum
ladder holds station with an empty cone, so breaking line of sight defeats all
six of them and always has. It is the one demand the old ladder cannot make, and
on paper it was the best rung on the new one.

Over 48 starts against five live champions:

```
             beam00  beam01  beam02  beam03  msi00
bruiser          48      35       6      48     48
hunter           48      35       6      48     48
```

Champion for champion, down to the single draw on beam01. The added competence
never fired once, because **a champion bred to fight never breaks contact**, so
the two rungs are one rung. Two identical columns on a profile are worse than one
column, because they read as corroboration.

It was replaced by `marksman`, which holds fire until the shot is inside 11
degrees and 180 m instead of the 26 degrees at any range every other rung on both
ladders uses. The magazine is four interceptors for a whole engagement and two
hits kill, so fire discipline is a competence that fires in every engagement
rather than only in the ones nobody has.

⚠ **AND THE ORDER WAS GUESSED WRONG AGAIN.** Written order was bruiser, harrier,
circler, swooper, leader, on the reasoning that closing in three dimensions is
the smallest addition. Measured, out of 240:

```
circler   227     easiest
harrier   202
marksman  192
bruiser   185
swooper   139
leader    130     hardest
```

`circler` is the bottom rung and was written third. This is `D.4` a second time,
in the same repository, by the same hand, having read `D.4` that morning.

⚠⚠ **WHERE IT IS BLIND, STATED BEFORE IT IS USED.** Three of eight random
controllers sweep `circler`, `bruiser`, `marksman` and nearly `harrier`. Those
four separate a champion from a crash and little else. The resolution is real and
it lives in `swooper` and `leader`, which separate all five champions from each
other and from the best random controller. `D.6` raised this against the first
ladder; the difference is that there the HARDEST rung was maxed by random genomes
and here the hardest two are not.

The reference champions and the raw sweep are committed, because a measured order
whose reference set was thrown away is an asserted order with extra steps.

**ELI5.** Someone wrote six new exam questions and was proudest of the sixth. When
they tried the paper on five real pupils, the sixth question got exactly the same
marks as the fourth, from every pupil, because it tested something no pupil ever
does. It was thrown out and replaced. Then the questions turned out to be in the
wrong order too: the one thought easiest was the hardest. The lesson is not about
these questions. It is that you cannot tell what a question measures by reading
it.

## I.22: the exam was one of the things the islands were breeding against

`trainer:opponents/1` returns `drone_drills:kinds() ++ roster`. `benchmark:rungs/0`
returned that same `drone_drills:kinds()`. The frozen exam was six of the
opponents the trainer selects against, over the same 48 start geometries, and had
been since the trainer was written.

Four opponents are drawn per round without replacement. From the roster depths
the fleet published on 2026-08-08:

| island | roster | drill share of pool | rounds drawing at least one exam rung |
|---|---|---|---|
| beam00 | 85 | 6.6% | ~24% |
| beam01 | 73 | 7.6% | ~28% |
| beam02 | 75 | 7.4% | ~27% |
| beam03 | 201 | 2.9% | ~11% |
| msi00 | 215 | 2.7% | ~11% |

⚠ **IT WAS PROMISED IN FOUR PLACES AND ENFORCED IN NONE.**
`drone_drills.erl`'s header said "nothing ever trains against them".
`benchmark.erl` was built on that sentence. `CHARTER.md` promises "a frozen
benchmark it never trains against, which is the only number on this island that
may be called improvement". `DESIGN_THE_ROSTER_AND_THE_RAID.md` repeats it. And
`D.7` published, as a finding, the sentence **"the population improved against an
exam it never trains on"**.

⚠⚠ **THE CHARTER WAS NOT WRONG, AND THAT IS THE INTERESTING PART.** It asks for
two things: an opponent set that *includes scripted drills*, and a benchmark that
is *never trained against*. Both are right. They are consistent only if the
scripted drills in the first are not the rungs of the second, and nothing in the
code said so, so one set of six quietly served both. The defect is not a wrong
decision. It is a correct decision with no mechanism.

**What was done.** `drone_drills` keeps its real job, the curriculum, and is
relabelled rather than withdrawn: performance against it is a real quantity and
is not improvement. `drone_trials` is the held-out exam, and `trials_tests`
asserts that no rung of it ever appears in `trainer:opponents/1`. That guard was
verified by putting one there and watching it go red.

⚠⚠⚠ **THIS DOES NOT EXPLAIN `D.16`, AND THE TEMPTING VERSION IS ALREADY DEAD.**
"The fleet solved the exam because it trains on the exam" would be a tidy story.
beam03 and msi00 leak at the same rate, about 11%, and sit at opposite ends of
the exam. Whatever `D.16` is, the leak alone is not it.

**Corrections owed to earlier entries.** `D.7` and `D.16` are both readings
off a contaminated instrument. None is withdrawn: they measured something real,
which is performance against the curriculum. What may not be said of any of them
is "improvement", which was the whole reason the number existed.

**ELI5.** A school promised that its end-of-year exam would use questions nobody
had seen, so that a good mark meant a pupil had actually learnt. The promise was
written in four different handbooks, and nobody ever checked the question paper
against the homework. About a quarter of the homework was the exam questions. The
fix is not a better promise: it is a second question paper, locked away, and a
rule that fails loudly if a question ever appears in both.

## I.21: it was never a lineage, and the module written to make it one had never once worked

Every island in this archipelago has been starting its population again from
seed on every deploy, since `roster_log` was written. Measured on `beam01` on
2026-08-07: a durable stream **1,111 events deep**, a roster of **229** in memory,
and `roster_log:restore/2` returning

```erlang
{error, {restore_failed, error, {badmap, {event, <<"019fd26a-...">>, <<"roster_snapshotted">>, ...}}}}
```

The snapshots were all there. Nothing had ever read one.

**Three faults, and each one hid the next.**

1. **`reckon_gater_api:stream_forward/4` returns `#event{}` records, not maps.**
   The reader called `maps:find/2` and raised `badmap` on the first event of every
   restore. It did this under a comment explaining, with care, why it accepted
   *two* key shapes: "events come back from the gater as maps whose keys may be
   atoms or binaries". Both guesses were wrong, and the considered tone of the
   comment is what made it read as settled. `I.19`, third instance.
2. **The caller swallowed the error.** `kept(Island, {error, _Why}) -> Island` is
   the right behaviour (an island that cannot read its log must still start)
   attached to no reporting at all. There was no log line, no counter, no field.
3. **The only published evidence agrees with both outcomes.** Roster depth. A
   restored lineage and a fresh island filling up from seed both show a number
   that climbs. There is no depth at which one looks wrong.

A fourth was waiting underneath: restore read `stream_forward(_, _, 0, 5000)`,
forward from the beginning and capped, not the backward scan to the newest
snapshot that the module's own header describes. At 1,111 events the cap had not
bitten. At 5,000 it would have started silently restoring ancient state.

**What it cost.** The tick, every counter on the island, and the population
itself, on every container recreate. The generation stamp added the day before
this was found measures breeding *since the last deploy*, so a node that gets
deployed more often looks younger. `D.15` asks why the frozen exam swings a
hundred points in a day on a champion `benchmark_sitter` says was bred locally.
One candidate is now that the champion had been bred from scratch that morning.

**Why nothing caught it.** The module had a test for its stream NAME and none for
its fold. No test ever fed it an event, so no test ever encountered the shape.
The fix ships `roster_log:rebuild/2`, a pure seam from events to state, and
eleven tests that build real `#event{}` records from the library's own header.
Reverting the reader turns ten of them red with the production `badmap`.

**ELI5.** Someone wrote a diary every night so they would remember their life,
and every morning they tried to read it and the book fell open at a page they
could not understand, so they shrugged and started the day as a stranger. They
never mentioned it to anybody, because starting fresh feels exactly like waking
up. The diary was full the whole time. Nobody had ever checked that the reading
worked, only that the writing did.

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
  never raided back is the exact signature of `I.24`, an advertisement that never
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

