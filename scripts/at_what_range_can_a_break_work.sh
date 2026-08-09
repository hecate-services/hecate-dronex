#!/usr/bin/env bash
#
# At what LAUNCH RANGE does a maximum-rate break start beating the interceptor?
#
# ⚠ WHY THIS EXISTS, AND WHY `sweep_the_interceptor.sh' CANNOT ANSWER IT. That
# sweep varies the weapon's REACH and reads two numbers, hit rate at 50 m and at
# 300 m. When reach is short, the 300 m number goes to zero because the missile
# RAN OUT OF FUEL, which looks identical to a target that dodged it. So the sweep
# cannot separate "was broken" from "never arrived", and on 2026-08-09 it was
# read as if it could.
#
# The question here is different and is the one that decides how far the weapon
# should reach: a drone under a maximum-rate turn needs TIME to swing out of the
# seeker's 60 degree field of view, and time of flight is what a launch range
# buys it. Below some range there is not enough of it and the weapon cannot be
# beaten by any amount of flying.
#
# So this holds reach FIXED AND LONG, at 600 m, where fuel never limits anything,
# and reads the whole table of launch ranges. Every number that comes back is
# about guidance against manoeuvre, which is the thing being asked about.
#
# ⚠⚠ IT IS A DIAGNOSTIC AND NOTHING IS TUNED ON IT. `CHARTER.md' rule 3: the
# whole table is printed, including the arms that say nothing.
#
# Usage:
#   scripts/at_what_range_can_a_break_work.sh
#   scripts/at_what_range_can_a_break_work.sh 30      # a 120 m weapon instead
set -uo pipefail
cd "$(dirname "$0")/.."

TTL=${1:-150}
SRC=apps/hecate_dronex/src/fly_the_airspace/airspace.erl
BEAM=_build/default/lib/hecate_dronex/ebin/airspace.beam
TMP=$(mktemp -d)

# ⚠ RESTORE ON EVERY EXIT PATH INCLUDING THE FAILURES. This overwrites a build
# artefact in place, so an interrupted run that skipped the restore would leave
# the tree compiled against a weapon nobody chose, and the next `rebar3 eunit'
# would measure it without saying so.
restore() {
    [ -f "$TMP/orig.beam" ] && { cp "$TMP/orig.beam" "$BEAM"; touch "$BEAM"; }
    rm -rf "$TMP"
}
trap restore EXIT

cp "$BEAM" "$TMP/orig.beam"
export ERL_LIBS="${ERL_LIBS:-$PWD/_build/default/lib}"

erlc -DINTERCEPTOR_TTL="$TTL" -I apps/hecate_dronex/include -o "$TMP" "$SRC" || exit 1
cp "$TMP/airspace.beam" "$BEAM"
touch "$BEAM"

echo
echo "Interceptor reach fixed at $(( TTL * 4 )) m, so fuel is not what is being measured."
echo "The shooter fires once and holds station. The target breaks or runs."
echo
scripts/can_a_drone_dodge_an_interceptor.escript
