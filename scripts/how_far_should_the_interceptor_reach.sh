#!/usr/bin/env bash
#
# How far should the guided interceptor reach? Print every arm.
#
# ⚠ WHY THIS EXISTS. On 2026-08-09 the weapon was cut from 600 m to 60 m in one
# step, on an argument about counterplay that `at_what_range_can_a_break_work.sh`
# then showed to be false: a maximum-rate break never beats the interceptor at
# any range, so reach cannot be chosen to protect a dodge that does not exist.
# What reach actually decides is HOW CLOSE A CONTROLLER MUST FLY TO EARN A HIT,
# and nobody has measured where 60 m sits on that curve against where the
# candidates do.
#
# ⚠⚠ CHARTER RULE 3. A constant is chosen on VIABILITY and the whole sweep is
# published, including the arms that say the current value was fine. It is never
# set to whichever value produced a number somebody liked. So this prints the
# control at the SHIPPED value first, then every candidate, and picks nothing.
#
# The quantity to read is the LAUNCH RANGE at which the hit rate falls off, per
# arm. Reach in metres is `TTL * 4` exactly (the interceptor flies 4 m per tick),
# so an arm's own reach is marked in the header and any zero beyond it is fuel
# rather than flying.
#
# Usage:
#   scripts/how_far_should_the_interceptor_reach.sh
#   TTLS="15 30" scripts/how_far_should_the_interceptor_reach.sh
set -uo pipefail
cd "$(dirname "$0")/.."

# 15 is the SHIPPED value and it is here as the control. Without it the four
# candidates are four numbers with nothing to be better or worse than.
TTLS=${TTLS:-"15 20 25 30 40"}

for TTL in $TTLS; do
    echo
    echo "=============================================================================="
    printf 'ARM: INTERCEPTOR_TTL = %s, so the weapon reaches %s m' "$TTL" "$(( TTL * 4 ))"
    [ "$TTL" = "15" ] && printf '   <- SHIPPED, the control'
    printf '\n'
    echo "=============================================================================="
    scripts/at_what_range_can_a_break_work.sh "$TTL"
done

echo
echo "Every arm above is printed. Nothing here chooses one."
