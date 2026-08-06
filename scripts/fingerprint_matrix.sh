#!/usr/bin/env bash
# Why does an island hold a neighbour's lease and still never raid it?
#
# `island_server:targets/1` admits a candidate only if ALL THREE hold:
#   1. the lease is fresh          (Now - At =< OPEN_FOR_MS)
#   2. the engine fingerprint is IDENTICAL to its own  (F =:= Mine)
#   3. the neighbour's roster is above the floor       (R > raid:floor_of())
#
# A fingerprint mismatch filters SILENTLY — no call, no timeout, no log on either
# side — which is REGISTER I.12's exact signature. This prints, per island, its
# own fingerprint and every lease it holds with the three verdicts, so the filter
# that is actually rejecting gets named rather than guessed at.
#
# ⚠ RETURN A TERM, DO NOT io:format. Under `eval`/erl_call the node's group
# leader is the CONTAINER's log, so anything printed lands there and the caller
# sees a bare `ok`. Only the value of the last expression comes back.
# ⚠ AND RETURN STRINGS, not binaries: erl_call renders a binary as a truncated
# #Bin<...> byte list, which is unreadable for a 32-byte digest.
set -euo pipefail

BOXES="${DRONEX_BOXES:-beam00 beam01 beam02 beam03}"

read -r -d '' EXPR <<'ERL' || true
S = sys:get_state(island_server),
O = maps:get(open_islands, S, #{}),
Now = erlang:monotonic_time(millisecond),
Mine = dronex_raid:fingerprint(),
Hex = fun(B) when is_binary(B) -> binary_to_list(binary:part(binary:encode_hex(B), 0, 16)); (X) -> X end,
Cut = fun(B) when is_binary(B) -> binary_to_list(binary:part(B, 0, 10)); (X) -> X end,
Floor = raid:floor_of(),
Leases = [ {Cut(Id), {age_ms, Now - At},
            {fp, Hex(maps:get(fingerprint, M, missing))},
            {fp_ok, maps:get(fingerprint, M, missing) =:= Mine},
            {roster, maps:get(roster, M, missing)},
            {roster_ok, maps:get(roster, M, 0) > Floor} }
           || {Id, {At, M}} <- lists:sort(maps:to_list(O)) ],
[{self, Cut(dronex_identity:island_id())},
 {my_fp, Hex(Mine)},
 {advertising, maps:get(advertising, S, missing)},
 {open, maps:get(open, S, missing)},
 {floor, Floor},
 {leases_held, length(Leases)},
 {targets_now, [Cut(T) || T <- island_server_targets_probe(S)]},
 {leases, Leases}].
ERL

# `targets/1` is private, so recompute its predicate inline rather than export it.
EXPR="${EXPR/\{targets_now, \[Cut(T) || T <- island_server_targets_probe(S)\]\},/\{targets_now, [Cut(Id) || {Id, {At, M}} <- maps:to_list(O), Now - At =< 300000, maps:get(fingerprint, M, missing) =:= Mine, maps:get(roster, M, 0) > Floor]\},}"

for box in $BOXES; do
  echo "──────── $box ────────"
  printf '%s\n' "$EXPR" > /tmp/fp.erl
  scp -q -o BatchMode=yes /tmp/fp.erl "rl@${box}.lab:/tmp/fp.erl" 2>/dev/null || true
  ssh -o BatchMode=yes -o ConnectTimeout=10 "rl@${box}.lab" bash -s <<'REMOTE' 2>&1 | grep -v "post-quantum\|store now\|openssh.com\|may need"
set -uo pipefail
docker cp /tmp/fp.erl hecate-dronex:/tmp/fp.erl >/dev/null 2>&1
timeout 60 docker exec hecate-dronex sh -c '/app/bin/hecate_dronex eval "$(cat /tmp/fp.erl)"' 2>&1 | head -20
REMOTE
  echo
done

echo "id -> name:  8ddd1f43ca=beam00  a6b1605a0f=beam01  60ac48650c=beam02  e649229946=beam03"
