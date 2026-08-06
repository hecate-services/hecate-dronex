#!/usr/bin/env bash
# Who fails to CALL whom. The raid handshake is the only RPC in the protocol;
# everything else is pub/sub. An island that can publish but cannot be CALLED
# raids happily and is never raided back, which is exactly the shape on the page.
#
# Each failure logs `[island] raid <id> was not accepted: {call_failed,{timeout,
# ... <<"dronex.raid.<TARGET>">> ...}}` and then dumps the whole raid party, so
# counting the procedure name per target gives the matrix.
set -euo pipefail

BOXES="${DRONEX_BOXES:-beam00 beam01 beam02 beam03}"
TAIL="${DRONEX_TAIL:-400000}"

for box in $BOXES; do
  echo "──────── $box ────────"
  ssh -o BatchMode=yes -o ConnectTimeout=10 "rl@${box}.lab" "TAIL='$TAIL' bash -s" <<'REMOTE' 2>&1 | grep -v "post-quantum\|store now\|openssh.com\|may need"
set -uo pipefail
docker logs --tail "$TAIL" hecate-dronex > /tmp/dx.log 2>&1 || true

echo -n "  log lines held:      "; wc -l < /tmp/dx.log
echo -n "  raids not accepted:  "; grep -ac "was not accepted" /tmp/dx.log || true
echo -n "  raids refused:       "; grep -ac "was refused" /tmp/dx.log || true
echo -n "  never settled:       "; grep -ac "never settled" /tmp/dx.log || true
echo -n "  accepted not hosted: "; grep -ac "could not host it" /tmp/dx.log || true
echo -n "  advertised for raids:"; grep -ac "advertised for raids" /tmp/dx.log || true
echo -n "  advertise lost:      "; grep -ac "can no longer advertise" /tmp/dx.log || true

echo "  failed CALL targets (count, island_id):"
grep -ao 'dronex\.raid\.[0-9a-f]\{32\}' /tmp/dx.log | sort | uniq -c | sort -rn | head -6 | sed 's/^/    /'

echo "  window covered:"
grep -a "WARNING REPORT" /tmp/dx.log | head -1 | sed 's/^/    first: /'
grep -a "WARNING REPORT" /tmp/dx.log | tail -1 | sed 's/^/    last:  /'
rm -f /tmp/dx.log
REMOTE
  echo
done
