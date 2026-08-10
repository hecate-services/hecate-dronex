#!/usr/bin/env bash
# Bring home a summary of every entry in every island roster, not just the champion.
#
# THIS EXISTS BECAUSE EVERY GENOME NUMBER WE HAVE RESTS ON ONE ENTRY PER ISLAND.
# `fetch_the_champions.sh` pulls `roster:best/1`, which is one genome out of a
# couple of hundred and is by construction the unrepresentative one. A tau band
# measured on five champions cannot tell a population fact from five accidents.
#
# ⚠ IT SUMMARISES ON THE ISLAND AND SHIPS BACK A SMALL BLOB. A full roster is
# about 1.46 MiB packed and 2 MB in base64, through an `eval` whose value has to
# be printed and then scraped back out of the output. The island already has
# `drone_genome` loaded, so the arithmetic happens there and what crosses the
# wire is a few hundred rows of {origin, generation, sorties, taus, w_min, w_max,
# mean_abs_w}.
#
# ⚠⚠ NOTHING BUT ERLANG BETWEEN THE QUOTES, NO APOSTROPHES, AND A TRAILING FULL
# STOP. A shell comment inside the eval is not a comment, it is part of the
# expression; an apostrophe ends the ssh argument early; and without the full
# stop the node answers "Incomplete form". All three have been walked into in
# this repository and each one reads like a fleet-wide outage.
#
# Usage:  scripts/fetch_the_rosters.sh [box ...]
#         OUT=somewhere scripts/fetch_the_rosters.sh
set -uo pipefail

BOXES="${*:-beam00.lab beam01.lab beam02.lab beam03.lab msi00.lab}"
OUT="${OUT:-rosters}"
CONTAINER="${CONTAINER:-hecate-dronex}"
RELEASE="${RELEASE:-hecate_dronex}"

mkdir -p "$OUT"

for box in $BOXES; do
  name="${box%%.*}"
  echo "── ${box}"

  ssh -n -o ConnectTimeout=10 -o BatchMode=yes "rl@${box}" '
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

    ct=$(command -v docker 2>/dev/null || command -v podman 2>/dev/null)
    [ -z "$ct" ] && { echo "NO_RUNTIME"; exit 1; }

    "$ct" exec '"${CONTAINER}"' /app/bin/'"${RELEASE}"' eval "
        R = gen_server:call(island_server, roster, 30000),
        Rows = [begin
                  {Ls, Genes} = roster:entry_genome(E),
                  {W, T} = drone_genome:split(Ls, Genes),
                  Ws = drone_genome:dequantize(W),
                  {roster:entry_origin(E), roster:entry_generation(E),
                   roster:entry_sorties(E), T,
                   lists:min(Ws), lists:max(Ws),
                   lists:sum([abs(X) || X <- Ws]) / length(Ws)}
                end || E <- roster:entries(R)],
        binary_to_list(base64:encode(term_to_binary(Rows, [compressed]))).
    " 2>&1 | grep -oE "[A-Za-z0-9+/=]{64,}" || echo NO_ANSWER
  ' 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded" > "${OUT}/${name}.raw"

  if grep -q NO_ANSWER "${OUT}/${name}.raw" || [ ! -s "${OUT}/${name}.raw" ]; then
    echo "  NO ANSWER (not the same as an empty roster)"
    rm -f "${OUT}/${name}.raw"
    continue
  fi

  tr -d " \n\r" < "${OUT}/${name}.raw" > "${OUT}/${name}.b64"
  rm -f "${OUT}/${name}.raw"
  printf "  roster summary saved, %s bytes of base64\n" "$(wc -c < "${OUT}/${name}.b64")"
done
