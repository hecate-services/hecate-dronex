# DroneX run archive

Captured immediately before `raid:target/2` was changed from `hd/1` to a random
draw. The run this preserves had a **degenerate attack graph**: each island
deterministically attacked the lowest-sorted island holding a fresh lease,
because `chosen(Others) -> {ok, hd(Others)}` took the head of a list built from
`maps:to_list/1` on a flatmap, whose keys come out in sorted term order.

`beam03` (`e649…`) sorted last for all three neighbours and was therefore
raided 3 times where the most-attacked islands were raided ~480 times.

⚠ **This is an END STATE, not a time series.** Nothing was recording vitals over
time. The per-island numbers are cumulative counters at the moment of capture.
Do not read a trajectory into them.

⚠ **The treatment is confounded with the machine.** beam00 is the fleet's only
16 GB node; the other three have 32 GB. Identical CPU (Celeron J4105, 4 cores).

Files:
  - `vitals-<island>.txt`  full vitals fact per island, as it arrived at the site
  - `leases-<island>.txt`  each island's open_islands, fingerprints, filter verdicts
  - `raids.txt`            the 64 raid rows the site held, without frames
  - `engagements.txt`      survivor/winner/length distribution over those 64
