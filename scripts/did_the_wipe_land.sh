#!/usr/bin/env bash
# Did the g4 wipe and the 120 m weapon actually reach the islands?
#
# ⚠ ASKED OF THE RUNNING NODE, NEVER INFERRED FROM THE IMAGE TAG. Both boxes types
# deploy off `:latest`, so an image NAME is the same string before and after a
# roll and proves nothing. What proves it is the value the island answers with.
#
# Three questions, because they fail independently:
#
#   lineage      $dronex:roster_g3 = the old one, the wipe has not landed here.
#                $dronex:roster_g4 = it has, and the roster starts from nothing.
#   fingerprint  Two islands with DIFFERENT digests refuse each other silently:
#                no call, no timeout, nothing logged on either side, `raids` just
#                stops moving. Register I.12. A split fleet is the failure mode
#                of a partial roll, and it looks healthy from every angle.
#   reach        15 ticks = the 60 m weapon, 30 = the 120 m one. This is the
#                thing that made the wipe necessary, so it is read directly
#                rather than trusted to have travelled with the rest.
#
# ⚠⚠ AND `rounds' IS PRINTED BECAUSE A FRESH LINEAGE CANNOT HAVE MANY. An island
# reporting `_g4' with four thousand breeding rounds behind it would mean the
# stream name moved and the state did not, which is a different bug from the one
# this script is looking for and would otherwise read as success.
set -uo pipefail

BOXES="${*:-beam00.lab beam01.lab beam02.lab beam03.lab msi00.lab}"

# ⚠ A TRAILING FULL STOP, and the value must BE the expression: `io:format' inside
# an `eval' prints on the island's own group leader, which is the container log,
# and hands back a bare `ok' here.
# ⚠⚠⚠ `rounds' IS BOUNDED AND CAUGHT, AND THE FIRST VERSION OF THIS SCRIPT WAS
# WRONG FOR WANT OF THAT. `sys:get_state/1' waits on the island's mailbox, which
# has reached six hundred thousand messages on this fleet before now. On beam00 it
# timed out, the whole tuple failed to evaluate, and the THREE CHEAP ANSWERS —
# lineage, fingerprint, reach, none of which touch `island_server' — were lost
# with it. The box that most needed reading was the one that reported nothing.
#
# A slow answer must never be able to take a fast one down with it. So the three
# constants are computed first and unconditionally, and `rounds' is a bounded call
# whose failure is a VALUE in the tuple rather than an exception over it.
EXPR='{roster_log:stream(),
       binary:part(binary:encode_hex(dronex_raid:fingerprint()), 0, 8),
       maps:get(interceptor_ttl, airspace:limits()),
       case catch island:rounds_of(maps:get(island, sys:get_state(island_server, 4000))) of
           N when is_integer(N) -> N;
           _ -> island_server_did_not_answer
       end}.'

for box in $BOXES; do
  echo "── ${box}"
  # ONE ssh per box.
  ssh -o ConnectTimeout=6 -o BatchMode=yes "rl@${box}" "
    export XDG_RUNTIME_DIR=/run/user/\$(id -u)
    export DBUS_SESSION_BUS_ADDRESS=unix:path=\${XDG_RUNTIME_DIR}/bus
    ct=\$(command -v podman 2>/dev/null || command -v docker 2>/dev/null)
    [ -z \"\$ct\" ] && { echo '  no container runtime'; exit 1; }

    c=\$(\$ct ps --format '{{.Names}}' 2>/dev/null | grep -i dronex | head -1)
    [ -z \"\$c\" ] && { echo '  NO RUNNING dronex CONTAINER (not the same as an answer)'; exit 1; }

    printf '  runtime     : %s\n' \"\$(basename \$ct)\"
    printf '  started     : %s\n' \"\$(\$ct inspect -f '{{.State.StartedAt}}' \"\$c\" 2>/dev/null)\"
    printf '  image id    : %s\n' \"\$(\$ct inspect -f '{{.Image}}' \"\$c\" 2>/dev/null | cut -c1-19)\"
    printf '  answers     : %s\n' \
      \"\$(\$ct exec \"\$c\" bin/hecate_dronex eval '${EXPR}' 2>&1 | tr -d '\n')\"
  " 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded"
  echo
done

echo "Reading it: roster_g4 + ttl 30 = rolled. roster_g3 + ttl 15 = not rolled."
echo "A MIX of the two across boxes is the worst case: the fingerprints differ,"
echo "so the two halves have silently stopped raiding each other."
