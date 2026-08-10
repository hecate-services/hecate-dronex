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
    # ⚠ THE FLEET IS NOT ONE RUNTIME. The lab boxes run docker; msi00 runs podman
    # under Quadlet. A probe naming one of them answers "nothing here" on the
    # other, which is how msi00 first read as a box with no island on it.
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    ct=$(command -v podman 2>/dev/null || command -v docker 2>/dev/null)
    [ -z "$ct" ] && { echo "  no container runtime"; exit 1; }

    "$ct" exec hecate-dronex /app/bin/hecate_dronex eval "
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
      %%
      %% ⚠ FOUR ELEMENTS: {ok, Roster, Tally, Archive}. The invader archive rides
      %% the same stream as the roster, so a restore brings both back. This probe
      %% matched three and nothing else did, so every island answered
      %% {probe_failed, error, {case_clause, ...}} after a roll -- four boxes
      %% reporting the same failure at once, which reads exactly like a
      %% fleet-wide restore failure. It was not one: the rosters had come back,
      %% and the crash dump was printing them. Found 2026-08-10 verifying the
      %% faber_tweann 2.4.0 roll. The older clauses are kept so this still says
      %% something useful when pointed at an island running an older image.
      %% NO APOSTROPHES IN THIS EVAL: it travels inside a single-quoted bash
      %% string, and one closing quote ends the ssh argument early.
      Restored = case roster_log:restore(S, roster:new(probe)) of
                   {ok, R, Tal, Arc} ->
                     {ok, roster:depth(R), maps:get(rounds, Tal, no_tally),
                      {invaders, maps:size(maps:get(entries, Arc, #{}))}};
                   {ok, R, Tal} -> {ok_no_archive, roster:depth(R), maps:get(rounds, Tal, no_tally)};
                   {ok, R} -> {ok_old_image, roster:depth(R)};
                   {error, Why} -> {error, element(1, Why)}
                 end,

      %% ⚠ THE LIVE FIELDS ARE ASKED DEFENSIVELY, EACH ON ITS OWN. They are
      %% gen_server calls into an island that is breeding, and a busy island
      %% misses the default 5 s. When they were inside the same try as the
      %% restore, one timeout discarded the restore answer that had ALREADY been
      %% computed and the probe reported {probe_failed, exit, {timeout, ...}} --
      %% nothing, in place of the one number it exists to report. An instrument
      %% must hand back what it knows even when part of the question fails.
      %% ⚠ NOT C:R. The variable R is bound by some clauses of the case above and
      %% not others, which makes it UNSAFE outside it, and erl_eval refuses the
      %% whole expression with unsafe_var rather than shadowing it.
      %% ⚠⚠ AND NO APOSTROPHES, WHICH THIS COMMENT ORIGINALLY HAD. The eval
      %% travels inside a single-quoted bash string, so one apostrophe ends the
      %% argument and bash reports a syntax error on the fun, twenty lines from
      %% the quote that actually broke. The warning was already written below and
      %% was still walked into.
      Ask = fun(F) -> try F() catch AskC:AskR -> {unavailable, AskC, element(1, AskR)} end end,
      #{shape => Shape, stream_depth => Depth, restore => Restored,
        live_roster => Ask(fun() -> roster:depth(island_server:roster()) end),
        live_rounds => Ask(fun() -> island:rounds_of(island_server:island()) end),
        live_tick => Ask(fun() -> island:tick_of(island_server:island()) end)}
      catch Class:Reason -> {probe_failed, Class, Reason}
      end,
      lists:flatten(io_lib:format(\"~P\", [Answer, 12]))." 2>&1 | tail -3
  ' 2>&1 | grep -v "post-quantum\|store now\|openssh.com/pq\|may need to be upgraded" | sed "s/^/  /"
  echo
done
