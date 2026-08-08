# The reference set the held-out ladder was frozen against

Five packed genomes, base64 of `drone_genome:pack/1`, one per island, pulled off
the live fleet on 2026-08-08 by `scripts/fetch_the_champions.sh`.

They are committed rather than ignored **because the rung order in
`drone_trials` was set by pointing these five at it.** `REGISTER D.4` is the
reason the order has to be measured at all, and a measured order whose reference
set has been thrown away is an asserted order with extra steps. The fleet breeds
a new champion every few minutes, so refetching would not reproduce this.

Raw output of the run that froze the order:
[`measurements/held_out_ladder_48_starts.txt`](../measurements/held_out_ladder_48_starts.txt).

To re-derive it:

```
rebar3 compile
ERL_LIBS=_build/default/lib scripts/what_does_the_ladder_look_like.escript 48 drone_trials champions
```

⚠ **These are a frozen reference, not a live sample.** They were the best entry
in each island's roster at one moment, and every island's roster has moved since.
Nothing about the fleet's *current* state may be read off them.
