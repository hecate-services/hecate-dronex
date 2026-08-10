#!/usr/bin/env bash
#
# Does changing a physics constant move the engine fingerprint? Print both.
#
# ⚠ WHY THIS EXISTS. `airspace:limits/0' feeds `dronex_raid:fingerprint_parts/0',
# so any change to a constant in it makes an island refuse every neighbour still
# running the old image — and REGISTER I.12 records what that looks like from
# outside: no call, no timeout, no log on either side, `raids' simply stays at
# zero. A physics change is therefore a FLEET-WIDE roll, and the operator should
# see the two digests before starting one rather than after.
#
# ⚠⚠ IT MEASURES RATHER THAN ASSERTS. "The fingerprint must have changed, it is
# derived from physics" is an argument, and arguments about this file have been
# wrong before: `term_to_binary/1' without `[deterministic]' made two islands on
# the IDENTICAL image disagree. Print the bytes.
#
# Usage:
#   scripts/does_the_fingerprint_move.sh                 # shipped vs the previous reach
#   scripts/does_the_fingerprint_move.sh 15 30
set -uo pipefail
cd "$(dirname "$0")/.."

BEFORE=${1:-15}
AFTER=${2:-30}
SRC=apps/hecate_dronex/src/fly_the_airspace/airspace.erl
BEAM=_build/default/lib/hecate_dronex/ebin/airspace.beam
TMP=$(mktemp -d)

# ⚠ THE SHIPPED BEAM GOES BACK ON EVERY EXIT PATH. This overwrites a build
# artefact in place, and an interrupted run that skipped the restore would leave
# the tree compiled against a weapon nobody chose.
# ⚠⚠ AND THE SOURCE IS TOUCHED LAST, so the restored beam is never newer than the
# source it came from. Without that, the next `rebar3 compile' after a constant
# is edited finds an up-to-date artefact and silently keeps the old weapon.
restore() {
    [ -f "$TMP/orig.beam" ] && { cp "$TMP/orig.beam" "$BEAM"; touch "$BEAM"; touch "$SRC"; }
    rm -rf "$TMP"
}
trap restore EXIT

cp "$BEAM" "$TMP/orig.beam"
export ERL_LIBS="${ERL_LIBS:-$PWD/_build/default/lib}"

digest() {
    erlc -DINTERCEPTOR_TTL="$1" -I apps/hecate_dronex/include -o "$TMP" "$SRC" || return 1
    cp "$TMP/airspace.beam" "$BEAM"
    touch "$BEAM"
    erl -noshell -eval '
        #{interceptor_ttl := T} = airspace:limits(),
        F = binary:encode_hex(dronex_raid:fingerprint()),
        io:format("  TTL ~p, reach ~p m   ~s~n", [T, T * 4, binary:part(F, 0, 16)]),
        halt().'
}

echo
echo "The engine fingerprint, at two reaches:"
echo
digest "$BEFORE"
digest "$AFTER"
echo
echo "Different digests mean an island on one image REFUSES an island on the other,"
echo "silently, so the five islands roll together or not at all."
