#!/usr/bin/env bash
# How long has each box been up, and how long has its island been up?
#
# A box uptime shorter than the island's is impossible, so the pair tells you
# WHICH reset: the machine, or only the container. An island uptime far shorter
# than its box means something restarted the unit, and rounds/generation say
# whether the roster survived it.
set -uo pipefail

BOXES="${*:-beam00.lab beam01.lab beam02.lab beam03.lab msi00.lab}"

for box in $BOXES; do
  echo "── ${box}"
  # ONE ssh per box. Everything the box knows, gathered in a single session.
  ssh -o ConnectTimeout=6 -o BatchMode=yes "rl@${box}" '
    # ⚠ ROOTLESS PODMAN AND systemctl --user NEED THIS OVER NON-LOGIN SSH. Without
    # it podman picks a different runroot and reports an EMPTY container list, which
    # reads exactly like "the island is down" and is not.
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

    printf "  box up      : %s\n" "$(uptime -p 2>/dev/null || echo unknown)"
    printf "  booted      : %s\n" "$(uptime -s 2>/dev/null || echo unknown)"

    systemctl --user list-units --all --no-legend --plain "*dronex*" 2>&1 |
      sed "s/^/  unit        : /"

    for u in $(systemctl --user list-units --all --no-legend --plain "*dronex*" 2>/dev/null | awk "{print \$1}"); do
      systemctl --user show -p ActiveState -p ActiveEnterTimestamp -p NRestarts "$u" 2>/dev/null |
        sed "s/^/    ${u} /"
    done

    echo "  --- podman"
    podman ps -a --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>&1 | grep -i dronex |
      sed "s/^/    /"
    for c in $(podman ps -a --format "{{.Names}}" 2>/dev/null | grep -i dronex); do
      printf "    %s started %s restarts %s\n" "$c" \
        "$(podman inspect -f "{{.State.StartedAt}}" "$c" 2>/dev/null)" \
        "$(podman inspect -f "{{.RestartCount}}" "$c" 2>/dev/null)"
    done
  ' 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded" | sed "s/^/  /"
  echo
done
