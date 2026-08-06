#!/usr/bin/env bash
# Did a newly rolled island actually JOIN, or is it merely running?
#
# ⚠ THE TWO ARE NOT THE SAME AND THE DIFFERENCE IS SILENT. An island whose engine
# fingerprint differs from its neighbours' is filtered out of every target list
# as an incompatible engine. Nothing errors, nothing logs, `/health` stays green,
# and its own `raids' counter climbs while `captures' and `defences' stay at
# zero. That is REGISTER I.12 and it cost a fleet two islands once already.
#
# So joining means all four of:
#   1. the image digest matches the neighbours'
#   2. the engine fingerprint matches
#   3. the neighbours hold ITS lease, and it holds THEIRS
#   4. the site has it on the board
set -euo pipefail

NEW_NODE="${1:-msi00.lab}"
NEW_RUNTIME="${NEW_RUNTIME:-podman}"
PEERS="${PEERS:-beam01 beam03}"
SITE_HOST="${BCN_HOST:-root@178.105.157.209}"
SITE_KEY="${BCN_KEY:-$HOME/.ssh/id_hetzner}"

PROBE='S=sys:get_state(island_server), O=maps:get(open_islands,S,#{}), M=dronex_raid:fingerprint(), H=fun(B) when is_binary(B), byte_size(B)>=6 -> binary_to_list(binary:part(binary:encode_hex(B),0,12)); (X) -> X end, C=fun(B) when is_binary(B) -> binary_to_list(binary:part(B,0,10)); (X) -> X end, [{me,C(dronex_identity:island_id())},{my_fp,H(M)},{adv,maps:get(advertising,S,none)},{op,maps:get(open,S,none)},{leases,[{C(I),maps:get(fingerprint,X,none)=:=M} || {I,{_A,X}} <- maps:to_list(O)]}].'

probe () {  # node runtime
    local node="$1" runtime="$2"
    printf '%s\n' "$PROBE" > /tmp/vprobe.erl
    scp -q -o BatchMode=yes /tmp/vprobe.erl "rl@${node}:/tmp/vprobe.erl"
    ssh -n -o BatchMode=yes "rl@${node}" "
        ${runtime} cp /tmp/vprobe.erl hecate-dronex:/tmp/vprobe.erl >/dev/null 2>&1
        timeout 60 ${runtime} exec hecate-dronex sh -c '/app/bin/hecate_dronex eval \"\$(cat /tmp/vprobe.erl)\"'
    " 2>&1 | grep -v "post-quantum\|store now\|openssh.com\|may need"
}

echo "===== 1. image digests ====="
printf '%-12s ' "${NEW_NODE}"
ssh -n -o BatchMode=yes "rl@${NEW_NODE}" \
    "${NEW_RUNTIME} image inspect ghcr.io/hecate-services/hecate-dronex:latest --format '{{.Digest}}'" \
    2>&1 | grep -v "post-quantum\|store now\|openssh\|may need"
for p in $PEERS; do
    printf '%-12s ' "$p"
    ssh -n -o BatchMode=yes "rl@${p}.lab" \
        "docker image inspect ghcr.io/hecate-services/hecate-dronex:latest --format '{{index .RepoDigests 0}}'" \
        2>&1 | grep -v "post-quantum\|store now\|openssh\|may need" | sed 's/.*@//'
done

echo
echo "===== 2+3. fingerprint, and who holds whose lease ====="
printf '%-12s ' "${NEW_NODE}"; probe "${NEW_NODE}" "${NEW_RUNTIME}"
for p in $PEERS; do printf '%-12s ' "$p"; probe "${p}.lab" docker; done

echo
echo "===== 4. is it on the site's board? ====="
ssh -o BatchMode=yes -i "$SITE_KEY" "$SITE_HOST" \
    "timeout 90 docker exec beam-campus-site /app/bin/beam_campus rpc '
     now = System.system_time(:millisecond)
     Dronex.islands()
     |> Enum.each(fn r ->
       v = Dronex.fact(r, :vitals) || %{}
       IO.inspect({Dronex.label(r), :quiet_s, div(now - (r.last_seen || now), 1000),
                   :gen, Map.get(v, \"generation\"), :rounds, Map.get(v, \"rounds\"),
                   :raids, Map.get(v, \"raids\"), :defences, Map.get(v, \"defences\"),
                   :captures, Map.get(v, \"captures\")})
     end)' 2>&1 | tail -8"
