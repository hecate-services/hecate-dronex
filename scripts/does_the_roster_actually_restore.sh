#!/usr/bin/env bash
# Does a deployed island restore its lineage, or does it start again every deploy?
#
# ⚠ EVERY ANSWER HERE IS BOUNDED, ON PURPOSE, AND THE BOUND IS `~P' NOT CARE.
# The first version pattern-matched `{ok, Evs}' and the badmatch printed 470 KB of
# packed genomes. The second called a function that does not exist and the `undef'
# printed the whole roster as its argument. Both times the flood came from the
# FAILURE path, which is exactly the path a probe is run to reach. So the whole
# body is wrapped and every result is formatted with `~P' at a fixed depth: a
# mistake in here can now cost a truncated line and nothing more.
#
# Three questions, in order:
#   shape    what `stream_forward/4' actually returns, by tuple size and tag
#   depth    how many events the stream holds against the scan cap it is read with
#   restore  what `roster_log:restore/2' comes back with, error reason only
#
# Usage:  scripts/does_the_roster_actually_restore.sh [node ...]
set -uo pipefail

BOXES="${*:-beam01.lab}"
SSH_USER="${SSH_USER:-rl}"

for box in $BOXES; do
  echo "── ${box}"
  ssh -n -o ConnectTimeout=10 "${SSH_USER}@${box}" '
    docker exec hecate-dronex /app/bin/hecate_dronex eval "
      Answer = try
      S = hecate_dronex_service:store_id(),
      Stream = roster_log:stream(),

      %% The SHAPE, never the contents: a tag and a size can be printed safely.
      Shape = case reckon_gater_api:stream_forward(S, Stream, 0, 1) of
                {ok, L} when is_list(L) -> {ok_list, length(L)};
                Tup when is_tuple(Tup) -> {tuple, tuple_size(Tup), element(1, Tup)};
                Other -> {not_a_tuple, is_list(Other)}
              end,

      %% Depth, counted a page at a time so the events are never all in hand.
      Count = fun C(From, Acc) ->
                case reckon_gater_api:stream_forward(S, Stream, From, 500) of
                  {ok, []} -> Acc;
                  {ok, Evs} -> C(From + length(Evs), Acc + length(Evs));
                  _ -> Acc
                end
              end,
      Depth = Count(0, 0),

      %% The restore itself. A roster is huge, so only its size is reported, and
      %% an error is reported by REASON with the payload dropped.
      %% restore/2 answers {ok, Roster, Tally} since the 2026-08-07 fix. The
      %% two-tuple clause is kept so this probe still says something useful when
      %% pointed at an island running the older image.
      %% NO APOSTROPHES IN THIS EVAL: it travels inside a single-quoted bash
      %% string, and one closing quote ends the ssh argument early.
      Restored = case roster_log:restore(S, roster:new(probe)) of
                   {ok, R, Tal} -> {ok, roster:depth(R), maps:get(rounds, Tal, no_tally)};
                   {ok, R} -> {ok_old_image, roster:depth(R)};
                   {error, Why} -> {error, element(1, Why)}
                 end,

      #{shape => Shape, stream_depth => Depth, restore => Restored,
        live_roster => roster:depth(island_server:roster()),
        live_rounds => island:rounds_of(island_server:island()),
        live_tick => island:tick_of(island_server:island())}
      catch Class:Reason -> {probe_failed, Class, Reason}
      end,
      lists:flatten(io_lib:format(\"~P\", [Answer, 12]))." 2>&1 | tail -3
  ' 2>&1 | grep -v "post-quantum\|store now\|openssh.com/pq\|may need to be upgraded" | sed "s/^/  /"
  echo
done
