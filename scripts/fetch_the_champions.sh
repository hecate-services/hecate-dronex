#!/usr/bin/env bash
# Bring each island's current champion home, packed, so a ladder can be graded
# against controllers that actually learnt something.
#
# ⚠ WHY THIS EXISTS. `REGISTER D.4' graded the first ladder with random
# controllers, which was right at the time because nothing had been bred yet. It
# is the wrong reference for a HARD ladder: a random controller scores nothing on
# every rung, and six zeroes look exactly like a beautifully graded instrument
# whose bottom rung nobody has reached. Only a trained controller can tell a hard
# ladder from an impossible one.
#
# ⚠⚠ ONE SSH PER BOX. Everything the box knows is gathered in a single session.
#
# ⚠⚠⚠ AND IT ASKS THE LIVE NODE VIA eval, WITH A TRAILING FULL STOP, RETURNING
# THE VALUE RATHER THAN PRINTING IT. Three separate traps, all of which look like
# a dead island:
#
#   rpc          takes MODULE FUNCTION ARGS here, not an expression, so an
#                expression comes back as {badrpc, {'EXIT', {undef, ...}}}
#   no full stop {error, "Incomplete form (missing .<cr>)??"}
#   io:format    prints on the RUNNING node, into its container log, and hands
#                back a bare "ok" here. The value has to BE the expression.
#
# eval on this release does reach the live node: whereis(island_server) answers
# with a pid on the hecate_dronex node.
#
# Writes one file per island: champions/<island>.b64, holding the base64 of
# drone_genome:pack/1. Reproducible input for
# scripts/what_does_the_ladder_look_like.escript.
#
# Usage:  scripts/fetch_the_champions.sh [box ...]
set -uo pipefail

BOXES="${*:-beam00.lab beam01.lab beam02.lab beam03.lab msi00.lab}"
OUT="${OUT:-champions}"
CONTAINER="${CONTAINER:-hecate-dronex}"
RELEASE="${RELEASE:-hecate_dronex}"

mkdir -p "$OUT"

for box in $BOXES; do
  name="${box%%.*}"
  echo "── ${box}"

  ssh -n -o ConnectTimeout=10 -o BatchMode=yes "rl@${box}" '
    # ⚠ ROOTLESS PODMAN AND systemctl --user NEED THIS OVER NON-LOGIN SSH.
    # Without it podman picks a different runroot and reports an EMPTY container
    # list, which reads exactly like "the island is down" and is not.
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

    # ⚠ THE FLEET IS NOT ONE RUNTIME. beam00-03 run docker; msi00 runs podman.
    ct=$(command -v docker 2>/dev/null || command -v podman 2>/dev/null)
    [ -z "$ct" ] && { echo "NO_RUNTIME"; exit 1; }

    # ⚠ A LONG CALL TIMEOUT, DELIBERATELY. gen_server:call defaults to 5 seconds
    # and a breeding round on a 1.5 GHz Celeron can exceed that, so the default
    # reports a timeout for an island that is merely busy.
    #
    # ⚠⚠ NOTHING BUT ERLANG BETWEEN THE QUOTES. A shell comment written inside
    # the eval string is not a comment, it is part of the expression, and the
    # parse error it causes is swallowed by the grep below and surfaces as
    # NO_ANSWER on all five boxes at once. That reads exactly like a fleet-wide
    # outage and it cost a debugging round here.
    #
    # ⚠⚠⚠ grep -oE, SO NOTHING HAS TO QUOTE A DOUBLE QUOTE. eval hands back an
    # Erlang string literal with its quotes. Stripping them with tr inside a
    # single-quoted remote body needs three levels of escaping and died at parse
    # time twice. Matching the base64 and ignoring what surrounds it needs none.
    "$ct" exec '"${CONTAINER}"' /app/bin/'"${RELEASE}"' eval "
        R = gen_server:call(island_server, roster, 30000),
        binary_to_list(base64:encode(drone_genome:pack(roster:entry_genome(roster:best(R))))).
    " 2>&1 | grep -oE "[A-Za-z0-9+/=]{64,}" || echo NO_ANSWER
  ' 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded" > "${OUT}/${name}.raw"

  if grep -qE "^[A-Za-z0-9+/=]{64,}$" "${OUT}/${name}.raw"; then
    grep -E "^[A-Za-z0-9+/=]{64,}$" "${OUT}/${name}.raw" > "${OUT}/${name}.b64"
    rm -f "${OUT}/${name}.raw"
    printf "  champion saved, %s bytes packed\n" \
      "$(base64 -d < "${OUT}/${name}.b64" | wc -c)"
  else
    echo "  no champion:"
    sed 's/^/    /' "${OUT}/${name}.raw"
  fi
done
