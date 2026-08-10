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
# ⚠⚠ AND THE SOURCE IS TOUCHED AFTER THE BEAM, WHICH IS THE STALE-BEAM TRAP IN
# ITS THIRD COSTUME. Restoring a beam and touching it leaves a build artefact
# NEWER than the source it came from, so the next `rebar3 compile' after somebody
# edits a constant decides there is nothing to do and silently keeps the old
# weapon. Measured 2026-08-10: `INTERCEPTOR_TTL' was edited 15 -> 30, two clean
# compiles reported success, and `airspace:limits/0' kept answering 15.
restore() {
    [ -f "$TMP/orig.beam" ] && { cp "$TMP/orig.beam" "$BEAM"; touch "$BEAM"; touch "$SRC"; }
    rm -rf "$TMP"
}
trap restore EXIT

cp "$BEAM" "$TMP/orig.beam"
export ERL_LIBS="${ERL_LIBS:-$PWD/_build/default/lib}"

erlc -DINTERCEPTOR_TTL="$TTL" -I apps/hecate_dronex/include -o "$TMP" "$SRC" || exit 1
cp "$TMP/airspace.beam" "$BEAM"
touch "$BEAM"

echo
echo "Interceptor reach fixed at $(( TTL * 4 )) m."
# ⚠ THE DEFAULT ARM AND A SHORT ARM MEASURE DIFFERENT THINGS, AND SAYING SO IS
# THE WHOLE POINT OF THE SCRIPT. At 600 m the missile never runs dry inside the
# table, so every zero is guidance losing to manoeuvre. At a short reach a zero
# past the fuel is the missile never arriving, which looks identical in the
# column and is not the same finding. This line used to claim "fuel is not what
# is being measured" whatever TTL it was handed, which was false for exactly the
# runs somebody would reach for this script to make.
if [ "$TTL" -ge 150 ]; then
    echo "Nothing in the table is fuel-limited, so every miss is guidance losing to manoeuvre."
else
    echo "⚠ Reach is SHORTER than the far end of the table, so a zero past $(( TTL * 4 )) m"
    echo "  is the missile never arriving, not a target out-flying it."
fi
echo "The shooter fires once and holds station. The target breaks or runs."
echo
scripts/can_a_drone_dodge_an_interceptor.escript
