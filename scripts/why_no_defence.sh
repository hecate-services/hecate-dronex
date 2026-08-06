#!/usr/bin/env bash
# Why does one island never get raided, while it raids others happily?
#
# Two mechanisms produce that shape and they are distinguishable from the LOGS:
#
#   A. nobody hears its "open" lease  -> attackers never try, and NOTHING is
#      logged anywhere. Silence on both sides.
#   B. attackers hear it, call, and the call is forwarded to a stale station
#      route and never answered -> the ATTACKERS log "was not accepted" /
#      "never settled" naming that island.
#
# So: count what each island logged, and count who each island's failures name.
set -euo pipefail

BOXES="${DRONEX_BOXES:-beam00 beam01 beam02 beam03}"
SINCE="${DRONEX_SINCE:-3 hours ago}"
UNIT="${DRONEX_UNIT:-hecate-dronex}"

for box in $BOXES; do
  echo "════════════════════════════════════════════════════"
  echo "  $box"
  echo "════════════════════════════════════════════════════"

  ssh -o BatchMode=yes -o ConnectTimeout=10 "rl@${box}.lab" \
    "SINCE='$SINCE' UNIT='$UNIT' bash -s" <<'REMOTE' 2>&1 || echo "  !! unreachable"
set -uo pipefail

CID=$(docker ps --filter "name=dronex" --format '{{.Names}}' | head -1)
if [ -z "$CID" ]; then
  CID=$(podman ps --filter "name=dronex" --format '{{.Names}}' 2>/dev/null | head -1)
  RUN=podman
else
  RUN=docker
fi
echo "  container: ${CID:-NONE} (${RUN:-none})"
[ -z "$CID" ] && { systemctl --user list-units 'hecate-dronex*' --no-pager 2>/dev/null | head -5; exit 0; }

$RUN ps --filter "name=$CID" --format '  status: {{.Status}}'

LOG=$($RUN logs --since "$SINCE" "$CID" 2>&1)

echo "  --- advertising ---"
printf '%s\n' "$LOG" | grep -c "advertised for raids"        | sed 's/^/  advertised_ok:      /'
printf '%s\n' "$LOG" | grep -c "can no longer advertise"     | sed 's/^/  advertise_lost:     /'
printf '%s\n' "$LOG" | grep "advertised for raids" | tail -1 | sed 's/^/  last: /'

echo "  --- raids this island LAUNCHED that went wrong ---"
printf '%s\n' "$LOG" | grep -c "was not accepted"            | sed 's/^/  not_accepted:       /'
printf '%s\n' "$LOG" | grep -c "was refused"                 | sed 's/^/  refused:            /'
printf '%s\n' "$LOG" | grep -c "never settled"               | sed 's/^/  never_settled:      /'
printf '%s\n' "$LOG" | grep -c "could not host it"           | sed 's/^/  accepted_not_hosted:/'

echo "  --- a sample of each failure, verbatim ---"
printf '%s\n' "$LOG" | grep -E "was not accepted|never settled|was refused" | tail -4 | sed 's/^/  /'

echo "  --- does anything name the unreachable island? ---"
printf '%s\n' "$LOG" | grep -icE "timeout|vanished|no_such_proc|not_advertised|no_route" \
  | sed 's/^/  transport_complaints:/'
printf '%s\n' "$LOG" | grep -iE "timeout|vanished|no_such_proc|not_advertised|no_route" | tail -3 | sed 's/^/  /'
REMOTE
  echo
done
