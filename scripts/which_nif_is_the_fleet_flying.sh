#!/usr/bin/env bash
# Which faber_tweann implementation is each live island actually flying?
#
# This decides the blast radius of a faber_tweann upgrade, so it is asked of the
# RUNNING nodes and never inferred from the Containerfile.
#
#   native (faber_nn_nifs)      CfC math is unchanged by 2.4.0. Behaviour-neutral,
#                               the roster stays comparable, no wipe.
#   fallback (tweann_nif_fallback)  CfC math CHANGES: the old fallback bound tau as
#                               _Tau and discarded it, used a different backbone,
#                               and returned tanh(state) rather than the state.
#                               That is a physics change and needs a new roster
#                               stream, the way $dronex:roster_g2 was minted.
#
# tweann_nif picks its implementation LAZILY on first use and caches it, so a node
# that has never evaluated a network answers with the choice this call forces. That
# is the same choice the island would make, which is what we want to know.
set -uo pipefail

BOXES="${*:-beam00.lab beam01.lab beam02.lab beam03.lab msi00.lab}"

# ⚠ eval needs a TRAILING FULL STOP, and io:format inside it prints on the running
# node and hands back a bare ok here, so the value we want must BE the expression.
EXPR='{tweann_nif:impl(), application:get_key(faber_tweann, vsn)}.'

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

    printf '  container   : %s\n' \"\$c\"
    printf '  image       : %s\n' \"\$(\$ct inspect -f '{{.Config.Image}}' \"\$c\" 2>/dev/null)\"
    printf '  impl, vsn   : %s\n' \
      \"\$(\$ct exec \"\$c\" bin/hecate_dronex eval '${EXPR}' 2>&1 | tr -d '\n')\"
  " 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded"
  echo
done
