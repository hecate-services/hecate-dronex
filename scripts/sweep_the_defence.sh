#!/usr/bin/env bash
# Sweep the static defence and print the WHOLE shape, including the settings
# that killed the game.
#
# ⚠ WHY THIS EXISTS. Item 8 owes a viability measurement and the criterion was
# written down before the dial was set: a competent attacking swarm must win a
# non-trivial fraction of raids against a competent defence. If home advantage
# is overwhelming, every island turtles, no genomes cross, and the charter's one
# idea dies quietly while the exhibit still looks busy.
#
# ⚠⚠ IT HAS FIVE DIALS, NOT ONE, AND FOUR OF THEM WERE FOUND BY BUILDING
# INSTRUMENTS RATHER THAN BY THINKING.
#
#   sensors    the original dial
#   reach      REGISTER D.13 — every raider is confirmed on frame 1 at the
#              shipped settings, so there is no approach phase to measure and a
#              sweep of station count alone would have reported a smooth,
#              confident, meaningless curve over a saturated network
#   ceiling    REGISTER D.12 — a station tests SLANT range from the ground, so
#              its radius at altitude z is sqrt(R^2 - z^2). Raising the ceiling
#              weakens every station without moving one
#   blast      design/DESIGN_THE_SECOND_WEAPON.md — STAGED, not yet physics
#   magazine   design/DESIGN_THE_SECOND_WEAPON.md — STAGED, not yet physics
#
# The last two are declared below and skipped, deliberately and loudly, rather
# than quietly omitted. When the second weapon lands they become live by adding
# values, not by editing this loop.
#
# ⚠⚠⚠ EVERY ARM BREEDS ITS OWN ROSTERS, WHICH IS WHY THIS IS SLOW AND WHY IT IS
# CORRECT. A swarm bred under five towers is not the swarm you get under two, so
# carrying one pre-trained roster across arms would answer "how does THIS swarm
# fare against various defences" rather than "is the game viable here".
#
# Usage:
#   scripts/sweep_the_defence.sh
#
#   SWEEP_SENSORS   station counts        (default "1 3 5 8")
#   SWEEP_REACH     metres                (default "150 250 350 500")
#   SWEEP_CEILING   metres                (default "300")
#   SWEEP_GENERATIONS / SWEEP_RAIDS       passed through to the probe
#
# One axis at a time around the shipped point, plus the sensors x reach cross,
# because those two are the pair that decides whether an approach phase exists
# at all. A full cross of five dials is not affordable and would not be read.

set -uo pipefail
cd "$(dirname "$0")/.."

UNIT=20480

# ⚠ THREE MODULES, NOT ONE, AND THE INTERCEPTOR SWEEP ONLY NEEDED ONE. The
# defence constants live in the header, so every module that INCLUDES it and
# uses them bakes them in at compile time. Recompiling only `airspace' would
# leave `ground_sensor' testing the shipped range while `airspace:limits/0'
# reported the swept one — the two would disagree, the fingerprint would
# describe neither, and the arm would silently measure a world that does not
# exist.
MODULES=(
    apps/hecate_dronex/src/fly_the_airspace/airspace.erl
    apps/hecate_dronex/src/defend_the_airspace/ground_sensor.erl
    apps/hecate_dronex/src/defend_the_airspace/ground_tracks.erl
)
EBIN=_build/default/lib/hecate_dronex/ebin
TMP=$(mktemp -d)

# ⚠ THE SHIPPED BEAMS GO BACK WHATEVER HAPPENS, and then the test profile is
# dropped. Leaving a swept build in place means the next honest run measures a
# constant nobody chose; leaving `_build/test' means `rebar3 eunit' tests the
# swept physics. Both have happened on this repository before.
restore() {
    for m in "${MODULES[@]}"; do
        base=$(basename "$m" .erl)
        if [ -f "$TMP/${base}.beam.orig" ]; then
            cp "$TMP/${base}.beam.orig" "$EBIN/${base}.beam"
            touch "$EBIN/${base}.beam"
        fi
    done
    rm -rf "$TMP" _build/test
}
trap restore EXIT

for m in "${MODULES[@]}"; do
    base=$(basename "$m" .erl)
    cp "$EBIN/${base}.beam" "$TMP/${base}.beam.orig"
done

export ERL_LIBS="${ERL_LIBS:-$PWD/_build/default/lib}"

# One arm: recompile the physics with these overrides, run the probe, print the
# machine-readable line. Everything is printed, including arms that refuse to
# compile and arms that killed the game.
arm() {
    local sensors="$1" reach_m="$2" ceiling_m="$3"
    local reach=$(( reach_m * UNIT )) ceiling=$(( ceiling_m * UNIT ))
    local ok=1

    for m in "${MODULES[@]}"; do
        if ! erlc -DSENSORS="$sensors" -DSENSOR_RANGE="$reach" -DARENA_Z="$ceiling" \
                  -I apps/hecate_dronex/include -o "$TMP" "$m" 2>/dev/null; then
            ok=0
        fi
    done

    if [ "$ok" -eq 0 ]; then
        printf "  %-8s %-7s %-8s %7s %7s %7s %7s   %s\n" \
               "$sensors" "${reach_m}m" "${ceiling_m}m" "-" "-" "-" "-" "DID NOT COMPILE"
        return
    fi

    for m in "${MODULES[@]}"; do
        base=$(basename "$m" .erl)
        cp "$TMP/${base}.beam" "$EBIN/${base}.beam"
        touch "$EBIN/${base}.beam"
    done

    local out result
    out=$(scripts/is_raiding_viable.escript 2>&1)
    result=$(echo "$out" | grep '^RESULT ' | tail -1)

    if [ -z "$result" ]; then
        printf "  %-8s %-7s %-8s %7s %7s %7s %7s   %s\n" \
               "$sensors" "${reach_m}m" "${ceiling_m}m" "-" "-" "-" "-" "PROBE FAILED"
        echo "$out" | tail -3 | sed 's/^/        /'
        return
    fi

    local field
    field() { echo "$result" | sed "s/.*[ ]$1=\([a-z0-9-]*\).*/\1/"; }

    printf "  %-8s %-7s %-8s %7s %7s %7s %7s   %s\n" \
           "$sensors" "${reach_m}m" "${ceiling_m}m" \
           "$(field seeda)>$(field compa)" "$(field seedb)>$(field compb)" "$(field rate)%" \
           "$(field secs)s" "$(field viable)"

    echo "$result" >> "$TMP/all"
}

echo
echo "Sweeping the static defence. Every arm is printed, including the dead ones."
echo "Shipped point is sensors=5 reach=350m ceiling=300m."
echo
echo "  ⚠ blast radius and gun magazine are dials 4 and 5 and are NOT swept here:"
echo "    they are not physics yet. See design/DESIGN_THE_SECOND_WEAPON.md. They"
echo "    land with this sweep, in one deliberate revision that resets the exam."
echo
printf "  %-8s %-7s %-8s %7s %7s %7s %7s   %s\n" \
       "sensors" "reach" "ceiling" "comp-a" "comp-b" "att" "cost" "viable"

SENSORS=${SWEEP_SENSORS:-"1 3 5 8"}
REACH=${SWEEP_REACH:-"150 250 350 500"}
CEILING=${SWEEP_CEILING:-"300"}

# The cross that matters: station count against reach decides whether a raid has
# an approach phase at all, which D.13 showed it currently does not.
for s in $SENSORS; do
    for r in $REACH; do
        for c in $CEILING; do
            arm "$s" "$r" "$c"
        done
    done
done

echo
if [ -f "$TMP/all" ]; then
    viable=$(grep -c 'viable=true' "$TMP/all" || true)
    total=$(wc -l < "$TMP/all")
    echo "  ${viable} of ${total} arms viable."
    if [ "$viable" -eq 0 ]; then
        echo
        echo "  ⚠ NO ARM IS VIABLE. That is a finding and not a failed run. Either"
        echo "    the rosters are not competent at this generation budget — check"
        echo "    the comp columns against the 40% floor — or the defence closes"
        echo "    the game at every setting tried, which is the failure"
        echo "    design/DESIGN_THE_STATIC_DEFENCE.md named in advance."
    fi
fi
echo
echo "  comp columns read SEEDED>BRED: the frozen-benchmark score of the best"
echo "  SEEDED genome, then of the best BRED one. Taking the best of 84 random"
echo "  genomes is already a selection step and scores well above zero, so the"
echo "  pair is what says whether the generation budget bought anything. Equal"
echo "  numbers mean it did not, and the arm reports that rather than hiding it."
echo
echo "  Both are an AWAY game with no network, so they are comparable across"
echo "  arms: they score the CONTROLLER and never the terrain. Below the 40%"
echo "  floor the attacker rate is a coin flip between two incompetent swarms"
echo "  and means nothing, which is why an arm can fail on competence alone."
echo
