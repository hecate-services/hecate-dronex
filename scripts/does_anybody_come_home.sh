#!/usr/bin/env bash
# Watch published raids and ask whether a raiding party ever survives one.
#
# ⚠ WHY THIS EXISTS. Within minutes of the second island going up, both islands
# were raiding, both were capturing genomes, and BOTH reported `raids_home = 0`.
# Every raider, every time, on both sides. That is either a physics finding or a
# wire bug, and the counters alone cannot tell the difference.
#
# ⚠⚠ THE BISECT IS THE POINT, AND IT IS ONE COMPARISON.
#
# `raiders_home' on the published fact is computed by the DEFENDER, from
# `defence:fates/2', BEFORE anything crosses the wire. `raids_home' on the
# attacker's vitals is computed AFTER the reply has been encoded, sent, decoded
# and matched against the party.
#
#   defender says home > 0, attacker says 0   ->  the REPLY loses information.
#                                                 Suspect the fate atoms: a CBOR
#                                                 round trip that turns
#                                                 `survived' into <<"survived">>
#                                                 makes every membership test
#                                                 false, silently.
#
#   defender says home = 0 too                ->  nobody survives the ENGAGEMENT.
#                                                 Not a bug. A finding, and a
#                                                 sharp one: controllers bred
#                                                 one-against-one are flying six
#                                                 against six for the first time.
#
# Reads only. It subscribes to the public realm as any spectator may, and
# publishes nothing.
#
# Usage:  scripts/does_anybody_come_home.sh [seconds]

set -uo pipefail

SECONDS_TO_WATCH="${1:-240}"
SITE_HOST="${SITE_HOST:-178.105.157.209}"
SITE_KEY="${SITE_KEY:-$HOME/.ssh/id_hetzner}"
STATION="${STATION:-https://station-se-stockholm.macula.io:4433}"
REALM="686fbbf84c5c33455764f4c07c642bd1b79ef4efc78455f61ac12936ca3bffe3"

echo "Watching dronex/raid for ${SECONDS_TO_WATCH}s via ${STATION}"
echo

ssh -n -o ConnectTimeout=20 -i "${SITE_KEY}" "root@${SITE_HOST}" \
  "docker exec beam-campus-site /app/bin/beam_campus rpc '
realm = Base.decode16!(\"${REALM}\", case: :lower)
{:ok, pool} = :macula.connect([\"${STATION}\"], %{})
Process.sleep(3000)
{:ok, _} = :macula_client.subscribe(pool, realm, \"dronex/raid\", self(), %{})

watch = fn watch, seen, deadline ->
  left = deadline - System.monotonic_time(:millisecond)
  if left <= 0 do
    seen
  else
    receive do
      {:macula_event, _ref, _topic, f, _meta} ->
        row = {f[\"island\"], f[\"attacker_id\"], f[\"winner\"], f[\"ticks\"],
               f[\"raiders\"], f[\"raiders_home\"]}
        IO.puts(:io_lib.format(\"  ~-10s defended vs ~-12s winner=~-9s ticks=~-5w sent=~w home=~w\",
          Tuple.to_list(row) |> Enum.map(fn
            v when is_binary(v) -> String.slice(v, 0, 12)
            v -> v
          end)))
        watch.(watch, [row | seen], deadline)
    after
      left -> seen
    end
  end
end

seen = watch.(watch, [], System.monotonic_time(:millisecond) + ${SECONDS_TO_WATCH} * 1000)
:macula.close(pool)

home = Enum.sum(Enum.map(seen, fn {_d, _a, _w, _t, _s, h} -> h || 0 end))
sent = Enum.sum(Enum.map(seen, fn {_d, _a, _w, _t, s, _h} -> s || 0 end))
IO.puts(\"\")
IO.puts(\"RESULT raids=#{length(seen)} sent=#{sent} home_per_defender=#{home}\")
IO.puts(
  cond do
    seen == [] -> \"  NO RAID FACTS SEEN. Either no raid happened in the window, or nothing is publishing them.\"
    home > 0 -> \"  THE DEFENDER SAW SURVIVORS. If the attacker still records raids_home=0, the REPLY is losing them.\"
    true -> \"  THE DEFENDER SAW NONE EITHER. Nobody survives a six-against-six. That is the engine, not the wire.\"
  end
)
'" 2>&1 | grep -vE "post-quantum|store now|upgraded|openssh.com|^\*\*"
