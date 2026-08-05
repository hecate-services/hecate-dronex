#!/usr/bin/env bash
# Sweep the guided interceptor's constants and print the WHOLE shape.
#
# ⚠ WHY THIS EXISTS. Register D.6: the interceptor has flattened two instruments,
# and `can_a_drone_dodge_an_interceptor.escript` measured why. At the shipped
# constants it hits 100% of the time at every range from 30 m to 450 m. The
# design claims a range gradient this weapon does not have, so either the
# constants are wrong or the design is.
#
# ⚠⚠ CHARTER RULE 3. A constant is chosen on VIABILITY and the whole sweep is
# published, including the arms that killed everything. It is never set to
# whichever value produced a number somebody liked. That is why this prints every
# arm rather than the winner.
#
# The criterion is fixed inside the probe, before any of this runs:
#   long range (300 m)  hit rate >= 50%    the weapon is worth carrying
#   close range (50 m)  hit rate =< 40%    closing is a defence
#   the gap             >= 40 points       the two weapons differ in kind
#
# Usage:
#   ERL_LIBS=$PWD/_build/default/lib scripts/sweep_the_interceptor.sh
#
# The three axes can be narrowed to walk a boundary, which is what SWEEP_TURNS
# was added for. The DEFAULTS are the published sweep; a narrowed run is a
# follow-up and says so in whatever record cites it.
#   SWEEP_SPEEDS="81920" SWEEP_TURNS="640 800 960" scripts/sweep_the_interceptor.sh

set -uo pipefail
cd "$(dirname "$0")/.."

SRC=apps/hecate_dronex/src/fly_the_airspace/airspace.erl
EBIN=_build/default/lib/hecate_dronex/ebin
BEAM=$EBIN/airspace.beam
TMP=$(mktemp -d)

# ⚠ THE SHIPPED BEAM IS PUT BACK WHATEVER HAPPENS. Leaving a swept build in place
# would mean the next honest run measures a constant nobody chose, which is the
# stale-beam trap in a new costume.
restore() {
    if [ -f "$TMP/airspace.beam.orig" ]; then
        cp "$TMP/airspace.beam.orig" "$BEAM"
        touch "$BEAM"
    fi
    rm -rf "$TMP"
}
trap restore EXIT

cp "$BEAM" "$TMP/airspace.beam.orig"

export ERL_LIBS="${ERL_LIBS:-$PWD/_build/default/lib}"

echo
echo "Sweeping the interceptor. Every arm is printed, including the dead ones."
echo
# ⚠ SPEED IS SWEPT BECAUSE ANGULAR RATE IS `a / v', NOT `v / r'. The first sweep
# varied only the turn acceleration and found the viable region at 12.5 m/s^2,
# about 1.25 g, which is implausibly sluggish for a munition and would fail
# charter rule 7's requirement that quantities be real ones. A FASTER missile is
# LESS agile at the same acceleration, which is both the physically ordinary way
# to build one and the axis that was missing.
#
# A drone turns at about 1.43 rad/s. A missile must be below that to be
# out-turned at all.
printf "  %-7s %-7s %-9s %-9s %7s %7s %6s   %s\n" \
       "speed" "turn" "radius" "rad/s" "close%" "long%" "gap" "viable"

for SPEED in ${SWEEP_SPEEDS:-81920 122880 163840}; do
 for TURN in ${SWEEP_TURNS:-7680 3840 1280}; do
  for TTL in ${SWEEP_TTLS:-150}; do
    if ! erlc -DINTERCEPTOR_SPEED="$SPEED" -DINTERCEPTOR_TURN="$TURN" \
              -DINTERCEPTOR_TTL="$TTL" \
              -I apps/hecate_dronex/include -o "$TMP" "$SRC" 2>/dev/null; then
        printf "  %-7s %-7s %-9s %-9s %7s %7s %6s   %s\n" \
               "$SPEED" "$TURN" "-" "-" "-" "-" "-" "DID NOT COMPILE"
        continue
    fi
    cp "$TMP/airspace.beam" "$BEAM"
    touch "$BEAM"

    OUT=$(scripts/can_a_drone_dodge_an_interceptor.escript 2>/dev/null)
    # ⚠ ONE MACHINE-READABLE LINE, NOT THE PROSE. Parsing the human output went
    # wrong twice: once taking the criterion thresholds for results, once on
    # Erlang printing a doubled percent sign. A script that reads another
    # script's prose is a mirror of its formatting.
    RESULT=$(echo "$OUT" | grep '^RESULT ')
    CLOSE=$(echo "$RESULT" | sed 's/.*close=\([-0-9]*\).*/\1/')
    LONG=$(echo "$RESULT" | sed 's/.*long=\([-0-9]*\).*/\1/')
    GAP=$(echo "$RESULT" | sed 's/.*gap=\([-0-9]*\).*/\1/')
    RADIUS=$(echo "$OUT" | grep 'interceptor  ' | sed 's/.*radius about \([0-9]*\) m.*/\1 m/')
    VERDICT=$(echo "$RESULT" | sed 's/.*viable=\(true\|false\).*/\1/')

    RATE=$(echo "$OUT" | grep 'interceptor  ' | sed 's/.*rate \([0-9.]*\) rad.*/\1/')
    printf "  %-7s %-7s %-9s %-9s %7s %7s %6s   %s\n" \
           "$(( SPEED / 1024 ))m/s" "$TURN" "$RADIUS" "$RATE" \
           "$CLOSE" "$LONG" "$GAP" "$VERDICT"
  done
 done
done

echo
echo "  turn is units per tick squared; 2560 is 50 m/s^2, the same as a drone."
echo "  rad/s is the ANGULAR rate, which is a/v and is what decides whether a"
echo "  target can turn inside the missile. A drone manages about 1.43 rad/s."
echo "  ttl fixed at 150 ticks: the earlier sweep showed 100 behaves identically"
echo "  and 60 kills long range outright, which is a range cutoff not a gradient."
echo
