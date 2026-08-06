#!/usr/bin/env bash
# Capture the state of a run before a change erases it.
#
# ⚠ THERE IS NO TIME SERIES. Nothing records vitals over time: the site holds the
# latest fact per island and the islands persist only the roster. So the only
# thing that can be archived is the END STATE, and once the islands restart it is
# gone. That is a limitation of this archive, not of the archiving.
#
# Written before fixing `raid:target/2`, because that fix erases the treatment the
# 2026-08-06 run accidentally ran: an attack graph fixed by id sort order.
set -euo pipefail

OUT="${1:-archive/$(date -u +%Y-%m-%dT%H%M%SZ)-run}"
BOXES="${DRONEX_BOXES:-beam00 beam01 beam02 beam03}"
SITE_HOST="${BCN_HOST:-root@178.105.157.209}"
SITE_KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"

mkdir -p "$OUT"
echo "archiving to $OUT"

cat > "$OUT/README.md" <<'MD'
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
MD

for box in $BOXES; do
  echo "  $box"
  scp -q -o BatchMode=yes \
    "$(dirname "$0")/../.archive-probe.erl" "rl@${box}.lab:/tmp/fp.erl" 2>/dev/null || true
  ssh -o BatchMode=yes -o ConnectTimeout=10 "rl@${box}.lab" \
    'docker cp /tmp/fp.erl hecate-dronex:/tmp/fp.erl >/dev/null 2>&1
     timeout 60 docker exec hecate-dronex sh -c "/app/bin/hecate_dronex eval \"\$(cat /tmp/fp.erl)\""' \
    2>&1 | grep -v "post-quantum\|store now\|openssh.com\|may need" > "$OUT/leases-${box}.txt" || true
done

echo "  site: vitals, raids, engagements"
ssh -o BatchMode=yes -i "$SITE_KEY" "$SITE_HOST" bash -s <<'REMOTE' > "$OUT/site.txt" 2>&1
timeout 150 docker exec beam-campus-site /app/bin/beam_campus rpc '
IO.puts("=== VITALS ===")
Enum.each(Dronex.islands(), fn row ->
  IO.puts("\n--- " <> Dronex.label(row) <> " ---")
  (Dronex.fact(row, :vitals) || %{}) |> Enum.sort()
  |> Enum.each(fn {k, v} -> IO.puts("  " <> String.pad_trailing(k, 26) <> inspect(v, charlists: :as_lists, limit: 30)) end)
end)

IO.puts("\n=== RAIDS (no frames) ===")
Enum.each(Dronex.raids(), fn r ->
  IO.inspect(%{raid: r.id, parts: Map.new(r.parts, fn {k, v} -> {k, Enum.map(v, &Map.drop(&1, ["frames"]))} end)},
             charlists: :as_lists, limit: :infinity)
end)

IO.puts("\n=== LEADERBOARD ===")
Enum.each(Dronex.leaderboard(), &IO.inspect(&1, charlists: :as_lists, limit: :infinity))
' 2>&1
REMOTE

echo "done: $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1)"
