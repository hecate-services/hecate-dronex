#!/usr/bin/env bash
# Watch a deployed island's own process, from the node, in ONE ssh session.
#
# ⚠ THE QUESTION IS WHETHER TRAINING STARVES PUBLISHING, and it cannot be
# answered from the outside. `island_server' schedules its next training round
# BEFORE it runs the current one, so if a round costs more than
# HECATE_DRONEX_TRAIN_MS the timer messages queue behind it, and the tick and
# publish timers are in the same mailbox. The symptom would be an island that
# looks perfectly healthy on /health and goes quiet on the mesh.
#
# So the three numbers that matter are sampled together:
#
#   message_queue_len   growing means the trainer is outrunning its own timer
#   sent / failed       the exercise counts: publishing at all, and succeeding
#   tick                the world clock; flat means the slot timer is starved
#
# ⚠ A LONG CALL TIMEOUT, DELIBERATELY. gen_server:call defaults to 5 seconds and
# a breeding round on a 1.5 GHz Celeron can exceed that, so the default reports
# `timeout' for an island that is merely busy. That is a measurement artefact and
# it looked like a wedged process the first time it was seen.
#
# Usage:  scripts/what_is_the_island_doing.sh [node] [samples] [seconds-apart]

set -uo pipefail

NODE="${1:-beam02.lab}"
SAMPLES="${2:-12}"
EVERY="${3:-5}"
SSH_USER="${SSH_USER:-rl}"

# ⚠⚠⚠ THIS PRINTED `no answer' FOR EVERY SAMPLE ON EVERY BOX AND THE ISLANDS WERE
# FINE. Found on 2026-08-09, verifying a fleet wipe, which is the worst possible
# moment to be told the fleet is not answering. Three faults, each of which alone
# produces exactly that output:
#
#   1. THE `eval' EXPRESSION HAD NO TRAILING PERIOD. The release's `eval' parses
#      a form and returns `{error, "Incomplete form (missing .<cr>)??"}' without
#      it. Nothing was ever run on the island.
#   2. `io:format' INSIDE `eval' DOES NOT COME BACK HERE. Its group leader is on
#      the target node, so the line lands in the ISLAND'S log. Even with the
#      period, this printed into a log nobody was reading. Recorded in the
#      operator notes twice before, and written again anyway.
#   3. `docker exec' IS HARDCODED and msi00 runs podman, so the fifth island
#      could never have answered whatever the other two faults did.
#
# ⚠ AND `|| echo "no answer"' CONVERTED ALL THREE INTO THE SAME REASSURING WORD.
# The `grep -E "^20"' dropped every error message, so a parse failure, a missing
# runtime and a genuinely wedged process were indistinguishable. Errors are now
# printed as they arrive.
#
# It returns a TERM and bash formats it. Nothing inside `eval' prints.
ssh -n -o ConnectTimeout=10 "${SSH_USER}@${NODE}" "
    set -u
    CT=\$(command -v docker 2>/dev/null || command -v podman 2>/dev/null)
    [ -z \"\$CT\" ] && { echo 'no container runtime on this box'; exit 1; }
    export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"
    export DBUS_SESSION_BUS_ADDRESS=\"unix:path=\${XDG_RUNTIME_DIR}/bus\"

    printf '%-20s %-6s %-7s %-8s %-7s %-7s %s\n' \
        time queue tick sent failed roster fn
    for i in \$(seq 1 ${SAMPLES}); do
        OUT=\$(\$CT exec hecate-dronex /app/bin/hecate_dronex eval 'P = whereis(island_server), [{message_queue_len, Q}, {current_function, {_M, F, _A}}] = process_info(P, [message_queue_len, current_function]), V = gen_server:call(island_server, snapshot, 30000), #{sent := Sent, failed := Failed} = gen_server:call(island_server, publishes, 30000), {Q, maps:get(tick, V), Sent, Failed, maps:get(roster, V), F}.' 2>&1)
        # The tuple, stripped of its braces, is already six ordered fields.
        echo \"\$OUT\" | sed 's/[{}]//g' | tr ',' ' ' | \
            awk -v t=\"\$(date +%FT%T)\" '{ printf \"%-20s %-6s %-7s %-8s %-7s %-7s %s\n\", t, \$1, \$2, \$3, \$4, \$5, \$6 }'
        sleep ${EVERY}
    done
"
