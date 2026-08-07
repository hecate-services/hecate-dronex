#!/usr/bin/env bash
# Wait for CI to publish, for watchtower to roll the fleet, then ask the islands
# whether they got their lineage back.
#
# THIS EXISTS SO THE ANSWER IS MEASURED RATHER THAN ASSUMED. `roster_log:restore/2'
# had never once succeeded and nothing noticed for weeks, because the only
# published evidence, roster depth, looks the same for a restored lineage and a
# fresh one filling up. The fix is worth exactly as much as the check that it
# worked on a real stream.
#
# ⚠ ONE SSH PER POLL, ONE POLL A MINUTE, ONE BOX. Watching the roll needs a
# repeated question and the standing rule is no ssh bombardment, so the wait
# watches a SINGLE node and only the full check afterwards touches the others.
set -uo pipefail

cd "$(dirname -- "$0")/.." || exit 1

WATCH_BOX="${WATCH_BOX:-beam01.lab}"
ALL_BOXES="${*:-beam00.lab beam01.lab beam02.lab beam03.lab}"
SSH_USER="${SSH_USER:-rl}"
MAX_WAIT_MIN="${MAX_WAIT_MIN:-25}"

image_on() {
  ssh -n -o ConnectTimeout=10 -o BatchMode=yes "${SSH_USER}@${WATCH_BOX}" \
    'docker inspect -f "{{.Image}}" hecate-dronex 2>/dev/null' 2>/dev/null | cut -c1-19
}

echo "── waiting for build-and-push"
run=$(gh run list --workflow=build-and-push --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status >/dev/null 2>&1
echo "   build ${run}: $(gh run view "$run" --json conclusion --jq .conclusion)"

before=$(image_on)
echo "── ${WATCH_BOX} is on ${before}, waiting for watchtower (max ${MAX_WAIT_MIN}m)"

for _ in $(seq 1 "$MAX_WAIT_MIN"); do
  sleep 60
  now=$(image_on)
  [ -n "$now" ] && [ "$now" != "$before" ] && { echo "   rolled to ${now}"; break; }
done

# The island restores in `init/1', so by the time it answers a call it has already
# either got its lineage back or logged that it did not.
echo
echo "── did the roster come back?"
./scripts/does_the_roster_actually_restore.sh $ALL_BOXES

echo
echo "── what the islands said about it"
for box in $ALL_BOXES; do
  echo "── ${box}"
  ssh -n -o ConnectTimeout=10 -o BatchMode=yes "${SSH_USER}@${box}" \
    'docker logs hecate-dronex 2>&1 | grep -i "ROSTER NOT RESTORED" | tail -3' 2>/dev/null |
    sed 's/^/    /'
done
echo "   (nothing printed above means no island reported a failed restore)"
