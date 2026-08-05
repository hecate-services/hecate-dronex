#!/usr/bin/env bash
# Break each boundary on purpose, one at a time, and assert the suite goes red.
#
# ⚠ WHY THIS EXISTS. Register INHERITED-3: a guard never seen to fail is not
# known to be a guard. A green suite proves the code passes its tests; it does
# not prove the tests would notice if the code stopped being right. Thirteen of the
# assertions in this repository are boundaries rather than behaviour, and a
# boundary that cannot be shown to bite is a comment with a function's syntax.
#
# ⚠⚠ TWO TRAPS THIS SCRIPT IS BUILT AROUND, both recorded on siblings.
#
#   A perturbation that only breaks the COMPILE is not a red check. Every
#   perturbation below produces code that compiles and is wrong, so a failure is
#   the test noticing rather than the compiler noticing. Each one is verified to
#   compile before its test is run.
#
#   `cp` restoring a backup leaves an OLDER mtime, so rebar3 serves a stale beam
#   and the next run passes against code that is no longer there. Every restore
#   here is followed by `touch`.
#
# Usage:  scripts/prove_the_guards_bite.sh
# Exit:   0 when every guard bit, 1 when any of them did not.

set -uo pipefail
cd "$(dirname "$0")/.."

SVC=apps/hecate_dronex/src/hecate_dronex_service.erl
MESH=apps/hecate_dronex/src/join_the_archipelago/dronex_mesh.erl
FACTS=apps/hecate_dronex/src/join_the_archipelago/dronex_facts.erl
ISLAND=apps/hecate_dronex/src/advance_an_island/island.erl
FIXED=apps/hecate_dronex/src/fly_the_airspace/fixed.erl
AIRSPACE=apps/hecate_dronex/src/fly_the_airspace/airspace.erl
SENSES=apps/hecate_dronex/src/pilot_a_drone/drone_senses.erl
PILOT=apps/hecate_dronex/src/pilot_a_drone/drone_pilot.erl
GENOME=apps/hecate_dronex/src/pilot_a_drone/drone_genome.erl

FAILURES=0
BROKEN=""

# ⚠ THE RESTORE TOUCHES, AND THEN DROPS THE TEST PROFILE, AND BOTH ARE NEEDED.
#
# `mv` back would leave the restored file with the backup's mtime, so rebar3
# would serve the PERTURBED beam afterwards and the next honest run would fail
# against code that is no longer on disk. `touch` fixes that for the profile the
# perturbation was compiled in.
#
# It is not enough. `rebar3 compile' builds the DEFAULT profile and `rebar3
# eunit' builds the TEST profile, which keeps its own copy of every beam. This
# script compiles in one and tests in the other, so a restore that refreshes only
# `_build/default' leaves `_build/test' holding the perturbations. That is
# exactly what happened on the first green run of this script: it reported all
# six guards biting, and the next plain `rebar3 eunit' failed four tests against
# sources that were already correct.
restore() {
    for f in "$@"; do
        if [ -f "${f}.guardbak" ]; then
            mv "${f}.guardbak" "$f"
            touch "$f"
        fi
    done
    rm -rf _build/test
}

trap 'restore "$SVC" "$MESH" "$FACTS" "$ISLAND" "$FIXED" "$AIRSPACE" "$SENSES" "$GENOME" "$PILOT"' EXIT

# Run one perturbation. $1 is the name, $2 the file, $3 a perl one-liner that
# breaks it, $4 the eunit module that must go red.
probe() {
    local name="$1" file="$2" script="$3" suite="$4"

    cp "$file" "${file}.guardbak"
    perl -0777 -i -pe "$script" "$file"
    touch "$file"

    if cmp -s "$file" "${file}.guardbak"; then
        echo "  SKIPPED  ${name}: the perturbation changed nothing (pattern drifted?)"
        BROKEN="${BROKEN}\n  ${name}: perturbation matched nothing"
        FAILURES=$((FAILURES + 1))
        restore "$file"
        return
    fi

    # A perturbation that does not compile proves nothing about the test.
    if ! rebar3 compile >/dev/null 2>&1; then
        echo "  SKIPPED  ${name}: the perturbation does not compile, so it is not a red check"
        BROKEN="${BROKEN}\n  ${name}: perturbation broke the compile"
        FAILURES=$((FAILURES + 1))
        restore "$file"
        rebar3 compile >/dev/null 2>&1
        return
    fi

    if rebar3 eunit --module="$suite" >/dev/null 2>&1; then
        echo "  DID NOT BITE  ${name}  (${suite} stayed green)"
        BROKEN="${BROKEN}\n  ${name}: ${suite} stayed green"
        FAILURES=$((FAILURES + 1))
    else
        echo "  bit           ${name}"
    fi

    restore "$file"
}

echo "Proving the guards bite."
echo

# 1. The publish path must not be able to kill the island.
#    hecate_om_identity:macula_client/0 is a gen_server call, so with hecate_om
#    down it EXITS with noproc rather than returning an error. Unwrapped, that
#    exit travels up through the publish timer and takes the roster with it.
probe "an unwrapped endpoint kills the island" "$MESH" \
  's/try pool\(hecate_om_identity:macula_client\(\)\)\n    catch Class:Reason -> \{error, \{no_hecate_om, Class, Reason\}\}\n    end\./pool(hecate_om_identity:macula_client())./s' \
  dronex_mesh_tests

# 2. A malformed public realm must refuse rather than fall back. Falling back
#    would publish PUBLIC facts onto the OPERATIONAL realm and report success,
#    which is the one outcome nobody would notice.
probe "a malformed realm falls back instead of refusing" "$MESH" \
  's/decode\(_Hex, _FleetRealm\) -> \{error, dronex_realm_not_64_hex\}\./decode(_Hex, FleetRealm) -> {ok, FleetRealm}./' \
  dronex_mesh_tests

# 3. store_id/0 and the evoq block in sys.config.src must name the same store.
#    They are in different files on different review paths, and disagreeing is
#    what put two of three fleet nodes into a boot-crash loop on a sibling.
probe "store_id drifts from the evoq block" "$SVC" \
  's/store_id\(\) -> dronex_store\./store_id() -> some_other_store./' \
  hecate_dronex_service_tests

# 4. The identity spec must ask for exactly the topics published. Authority in
#    two places is authority that drifts, and a sibling published on two topics
#    its spec did not name.
probe "the identity spec hardcodes its own topic list" "$SVC" \
  's/resources => dronex_facts:topics\(\),/resources => [<<"dronex\/anything">>],/' \
  hecate_dronex_service_tests

# 5. A zero must be published rather than omitted. CHARTER.md rule 4: an island
#    with an empty roster and an island that does not report a roster look
#    identical unless the zero goes out.
probe "a zero count is omitted from the fact" "$FACTS" \
  's/        roster => island:roster_depth\(Island\),\n//' \
  dronex_facts_tests

# 6. Nothing in this repository may reach mnesia or the genotype path.
#
#    ⚠ THE PERTURBATION IS EXPORTED, AND APPENDED AT THE END OF THE FILE, AND
#    NEITHER IS TIDINESS. This probe broke the compile twice before it worked,
#    and both times for a reason that is not about mnesia at all:
#
#      an unexported function nobody calls is an unused-function warning, and
#      this tree builds with warnings_as_errors
#
#      a function definition placed among the attributes puts `-export_type' and
#      `-record' AFTER the first function, which Erlang rejects outright
#
#    Both are the trap named at the top of this file, and both were caught by
#    this script's own compile check rather than by reading the output as a
#    result. A probe that does not compile is not evidence about anything.
probe "a module reaches into mnesia" "$ISLAND" \
  's/-export\(\[tick_of\/1, roster_depth\/1, capacity\/1, seed_of\/1\]\)\./-export([tick_of\/1, roster_depth\/1, capacity\/1, seed_of\/1]).\n-export([tables\/0])./; s/\z/\ntables() -> mnesia:system_info(tables).\n/' \
  faber_boundary_tests

# ⚠ PROBES 7 TO 9 EACH BROKE THE COMPILE ON THEIR FIRST WRITING, ALL THREE FOR
#    THE SAME REASON AND NONE OF IT ABOUT WHAT THEY TEST. Replacing the body of
#    a function ORPHANS the helpers it used to call, and an unreachable function
#    is an unused-function warning against warnings_as_errors. So a perturbation
#    has to leave the call graph intact: change what a LEAF returns, or add a new
#    exported function, never sever a branch.
#
#    That is the third and fourth time this trap has fired in this file. It is
#    the reason the compile check exists, and the reason its failure is reported
#    as SKIPPED rather than counted as a guard that bit.

# 7. The match path must hold no libm, no clock and no unseeded generator, or a
#    published raid stops being checkable by the island that flew into it. The
#    check is structural, so merely IMPORTING libm is the whole perturbation.
#    ⚠ IT PERTURBS AN EXISTING LEAF RATHER THAN APPENDING A NEW FUNCTION, and
#    that is robustness rather than style. The first version added an exported
#    `root/1' and had to name `fixed''s whole export list to do it, so adding any
#    function to that module silently stopped the probe from matching. Changing
#    what `clamp/3' returns needs no export and cannot drift.
#
#    ⚠⚠ AND IT DELIBERATELY DOES NOT CHANGE THE ANSWER: `* 0' means clamp still
#    returns exactly what it did. So only the STRUCTURAL check can catch this,
#    which is the whole point of having one, and a behavioural suite would stay
#    green while every published fight quietly stopped being portable.
#
#    ⚠⚠⚠ THE ARGUMENT MUST DEPEND ON A RUNTIME VALUE. `math:sqrt(1.0)' is
#    CONSTANT-FOLDED by the compiler, so no call reaches the beam's imports chunk
#    and the structural check is right to stay green: there genuinely is no libm
#    call at runtime. The first version of this probe used a literal, compiled
#    cleanly, and reported the guard as broken when the guard was correct.
probe "the match path reaches for libm" "$FIXED" \
  's/clamp\(V, _Lo, _Hi\) -> V\./clamp(V, _Lo, _Hi) -> V + trunc(math:sqrt(abs(V) + 1.0)) * 0./' \
  airspace_determinism_tests

# 8. A munition must be tested against the SEGMENT it travelled, not its end
#    point. It covers 3 m a tick before inheriting any launcher velocity, and two
#    hit radii span 4 m, so an end-point test tunnels straight through a drone it
#    struck squarely, more often the faster the shot. Forcing the parameter to
#    its upper bound is exactly "measure from the end point".
probe "the hit test uses the end point instead of the path" "$AIRSPACE" \
  's/clamped_t\(Num, _Den\) -> Num\./clamped_t(_Num, Den) -> Den./' \
  airspace_tests

# 9. Thrust is limited as a vector. Per-axis clamping hands out root three times
#    the thrust, available only diagonally, and a population finds it at once.
probe "thrust is clamped per axis instead of as a vector" "$FIXED" \
  's/shortened\(X, Y, Z, Max, Mag\) ->\n    \{X \* Max div Mag, Y \* Max div Mag, Z \* Max div Mag\}\./shortened(X, Y, Z, Max, _Mag) ->\n    {clamp(X, -Max, Max), clamp(Y, -Max, Max), clamp(Z, -Max, Max)}./s' \
  airspace_tests

# 10. A stranger's genome must be REFUSED rather than repaired. Clamping a weight
#     into range changes the genome, which changes what fought, which means the
#     published identifier no longer names the code that ran.
probe "a foreign genome is clamped instead of refused" "$GENOME" \
  's/usable\(_W\) -> false\./usable(_W) -> true./' \
  drone_pilot_tests

# 11. The input width must be enforced. network_evaluator pads a short input
#     layer in SILENCE and a short output vector falls back to a null command, so
#     a mismatched genome does not crash: it fights badly and produces a result
#     nobody can tell from a measurement.
#     ⚠ THE GUARD IS NARROWED RATHER THAN DELETED, so every variable in the
#     clause head stays used and the module still compiles. Deleting the clause
#     leaves `In' bound and unread, which is an unused-variable error against
#     warnings_as_errors and proves nothing about the test.
probe "a wrong-width genome is admitted" "$GENOME" \
  's/when hd\(Layers\) =\/= In -> \{error, wrong_input_width\}/when hd(Layers) =\/= In, In < 0 -> {error, wrong_input_width}/' \
  drone_pilot_tests

# 12. A drone is blind behind. The 120 degree cone is what makes yaw expensive
#     and gives the comms channel something to be for; widening it to 360 would
#     quietly remove the reason for half the design.
probe "the sensor cone becomes all-round vision" "$SENSES" \
  's/-define\(CONE_COS, 16384\)\./-define(CONE_COS, -32768)./' \
  drone_senses_tests

# 13. The genome must fully specify the controller, or a genome sent to another
#     island flies a different drone there and a raid means nothing. Register
#     `D.5': the CfC time constants were left to the process-global generator for
#     an afternoon and the only symptom was a benchmark that would not repeat.
probe "the time constants fall back to the generator" "$PILOT" \
  's/    network_evaluator:set_neuron_meta\(Weighted, meta\(Hidden, Out, Taus\)\)\./    _Unused = meta(Hidden, Out, Taus),\n    Weighted./' \
  drone_pilot_tests

echo
rebar3 compile >/dev/null 2>&1

if [ "$FAILURES" -eq 0 ]; then
    echo "All thirteen guards bit."
    exit 0
fi

echo "${FAILURES} guard(s) did not bite:"
printf '%b\n' "$BROKEN"
exit 1
