#!/usr/bin/env bash
# THE DECISIVE TEST for "island X raids but is never raided".
#
# The raid handshake is RPC, but WHO to call comes from the `opened` lease on the
# FLEET realm. Two failures produce the same page:
#
#   A. X's lease never reaches the others -> they never call, and NOTHING is
#      logged anywhere, on either side. Silence is the signature.
#   B. they call and the station drops it -> the CALLERS log timeouts naming X.
#
# No island's log names beam03's procedure except beam03's own, so (B) is out on
# the evidence. This asks each island directly: whose leases have you got?
set -euo pipefail

BOXES="${DRONEX_BOXES:-beam00 beam01 beam02 beam03}"
REL="${DRONEX_REL:-/app/bin/hecate_dronex}"

for box in $BOXES; do
  echo "──────── $box ────────"
  ssh -o BatchMode=yes -o ConnectTimeout=10 "rl@${box}.lab" "REL='$REL' bash -s" <<'REMOTE' 2>&1 | grep -v "post-quantum\|store now\|openssh.com\|may need"
set -uo pipefail

timeout 60 docker exec hecate-dronex "$REL" rpc '
S = sys:get_state(island_server),
Open = maps:get(open_islands, S, #{}),
Away = maps:get(away, S, #{}),
Self = dronex_identity:island_id(),
Short = fun (B) when is_binary(B) -> binary:part(B, 0, min(12, byte_size(B))); (X) -> X end,
io:format("  self:          ~s~n", [Short(Self)]),
io:format("  advertising:   ~p~n", [maps:get(advertising, S, missing)]),
io:format("  open (mine):   ~p~n", [maps:get(open, S, missing)]),
io:format("  raids away:    ~p~n", [maps:size(Away)]),
io:format("  leases held:   ~p~n", [maps:size(Open)]),
lists:foreach(fun (K) -> io:format("    knows open: ~s~n", [Short(K)]) end,
              lists:sort(maps:keys(Open)))
' 2>&1 | tail -14
REMOTE
  echo
done

echo "id -> name:  8ddd1f43ca=beam00  a6b1605a0f=beam01  60ac48650c=beam02  e649229946=beam03"
