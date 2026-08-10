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
# ⚠⚠ `rounds' IS PRINTED, AND IT IS NOT EVIDENCE OF ANYTHING ON ITS OWN. The
# tempting reading is "a fresh lineage cannot have many rounds, so a big number
# means the wipe did not land". That reading is FALSE and it cost an afternoon:
# these islands breed at roughly 1,500 rounds an hour, so a `_g4' lineage three
# hours old is legitimately at four to five thousand, and the public exhibit
# showing thousands of rounds was read as a fleet that had never rolled. It had
# rolled, inside four minutes, on all five boxes.
#
# The LINEAGE NAME is the answer. `rounds' is context.
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
#
# ⚠⚠⚠⚠ AND THE BOUND IS 30 SECONDS, NOT FOUR, BECAUSE FOUR ACCUSES A HEALTHY BOX.
# `what_is_the_island_doing.sh' has said since 2026-08-09 that a breeding round on
# a 1.5 GHz Celeron can exceed a short call timeout, and that reading that as a
# wedged process is a measurement artefact. This script was written with a 4
# second bound anyway, reported `island_server_did_not_answer' for beam00, and
# that was taken as evidence of a stuck island. The value is now named for what it
# means. It was not stuck: sampled over a hundred
# seconds, beam00's queue never exceeded 7, its tick advanced every sample and it
# was inside `evaluate_neurons_cfc' every time. It was busy.
#
# ⚠ THE WARNING EXISTED AND DID NOT TRAVEL, WHICH IS THE PART TO LEARN FROM. It
# lived in a comment in a DIFFERENT script, so writing a new one that asks the
# same process the same kind of question reproduced the same mistake from scratch.
# The wedge signature is a queue in the hundreds of thousands and a FLAT tick
# (register I.20), not a call that takes longer than you felt like waiting.
EXPR='{roster_log:stream(),
       binary:part(binary:encode_hex(dronex_raid:fingerprint()), 0, 8),
       maps:get(interceptor_ttl, airspace:limits()),
       case catch island:rounds_of(maps:get(island, sys:get_state(island_server, 30000))) of
           N when is_integer(N) -> N;
           _ -> island_server_busy_past_the_bound
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
