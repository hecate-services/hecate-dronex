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

ssh -n -o ConnectTimeout=10 "${SSH_USER}@${NODE}" "
    set -u
    printf '%-9s %-6s %-7s %-8s %-7s %-7s %s\n' \
        time queue tick sent failed roster fn
    for i in \$(seq 1 ${SAMPLES}); do
        docker exec hecate-dronex /app/bin/hecate_dronex eval '
            P = whereis(island_server),
            [{message_queue_len, Q}, {current_function, {_M, F, _A}}] =
                process_info(P, [message_queue_len, current_function]),
            %% 30s, not the 5s default: a busy island is not a wedged one.
            V = gen_server:call(island_server, snapshot, 30000),
            #{sent := Sent, failed := Failed} =
                gen_server:call(island_server, publishes, 30000),
            io:format(\"~s ~-6b ~-7b ~-8b ~-7b ~-7b ~p~n\",
                      [calendar:system_time_to_rfc3339(erlang:system_time(second),
                                                       [{unit, second}]),
                       Q, maps:get(tick, V), Sent, Failed, maps:get(roster, V), F])
        ' 2>&1 | grep -E '^20' || echo 'no answer'
        sleep ${EVERY}
    done
"
