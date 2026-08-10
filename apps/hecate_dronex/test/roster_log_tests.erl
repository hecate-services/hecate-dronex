%% @doc The fold that restores a lineage, tested against the SHAPE THE STORE
%% ACTUALLY RETURNS.
%%
%% ⚠ THIS FILE EXISTS BECAUSE ITS ABSENCE COST EVERY LINEAGE THIS PROJECT BRED.
%% `roster_log' was written, reviewed, deployed to five nodes and left running for
%% weeks while `restore/2' raised `badmap' on the first event of every attempt.
%% Nothing caught it, because nothing ever fed it an event. The module had a test
%% for its stream NAME and none for its fold.
%%
%% So the one rule here: every event is a real `#event{}' record built from the
%% library's own header, never a map standing in for one. A test that invents a
%% convenient shape tests the invention, which is exactly the mistake the module
%% made, and a test repeating it would have passed cheerfully beside the bug.
-module(roster_log_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

%%==============================================================================
%% Fixtures: the shapes the store returns, and the genomes it carries
%%==============================================================================

event(Version, Type, Data) ->
    #event{event_id = <<"ev">>,
           event_type = Type,
           stream_id = roster_log:stream(),
           version = Version,
           data = Data,
           metadata = #{}}.

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

%% Genomes differing in one gene, so their ids differ and nothing else does.
genome(N) ->
    Count = drone_genome:gene_count(topology()),
    {topology(), [N | lists:duplicate(Count - 1, 0)]}.

entry(N) ->
    roster:entry(genome(N), #{fitness => N, generation => N, origin => {bred, test}}).

packed(N) ->
    E = entry(N),
    #{id => roster:entry_id(E),
      genome => drone_genome:pack(roster:entry_genome(E)),
      generation => roster:entry_generation(E),
      fitness => roster:entry_fitness(E),
      origin => roster:entry_origin(E),
      sorties => roster:entry_sorties(E)}.

empty() -> roster:new(test, 8).

rebuild(Events) -> roster_log:rebuild(Events, empty()).

%%==============================================================================
%% The fault that ran in production for weeks
%%==============================================================================

%% ⚠ THE REGRESSION TEST. Put the map readers back into `type_of/1' and
%% `data_of/1' and this raises `badmap', exactly as five deployed islands did on
%% every boot. Verified red against the reverted code before being believed.
a_snapshot_event_restores_the_roster_test() ->
    {R, _T, _A} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), packed(2)], capacity => 8})]),

    ?assertEqual(2, roster:depth(R)).

%% A payload that is not a map fails LOUDLY rather than being skipped. Returning
%% `#{}' here would make the snapshot clause miss, fall to the catch-all, and
%% lose the roster in silence, which is the failure this module lived in.
a_payload_that_is_not_a_map_fails_loudly_test() ->
    Ev = event(0, <<"roster_snapshotted">>, <<"json bytes we cannot read">>),

    ?assertError({payload_not_a_map, <<"roster_snapshotted">>, {binary, 25}}, rebuild([Ev])).

%%==============================================================================
%% The fold
%%==============================================================================

%% A snapshot is full state, so it REPLACES rather than merges. An island that
%% folded snapshots together would carry every genome it ever evicted.
a_later_snapshot_replaces_an_earlier_one_test() ->
    {R, _T, _A} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), packed(2)], capacity => 8}),
                       event(1, <<"roster_snapshotted">>,
                             #{entries => [packed(3)], capacity => 8})]),

    ?assertEqual(1, roster:depth(R)).

the_tail_after_a_snapshot_is_replayed_test() ->
    {R, _T, _A} = rebuild([event(0, <<"roster_snapshotted">>, #{entries => [packed(1)], capacity => 8}),
                       event(1, <<"genome_admitted">>, packed(2)),
                       event(2, <<"genome_admitted">>, packed(3))]),

    ?assertEqual(3, roster:depth(R)).

an_eviction_in_the_tail_is_replayed_test() ->
    Gone = maps:get(id, packed(1)),
    {R, _T, _A} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), packed(2)], capacity => 8}),
                       event(1, <<"genome_evicted">>, #{id => Gone})]),

    ?assertEqual(1, roster:depth(R)),
    ?assertNot(roster:has(R, Gone)).

%% An event type written by a later image must not stop an older one booting: a
%% rollback that refuses to start is an outage, and the cost of skipping is a
%% roster that is visibly shallower.
an_unknown_event_type_is_skipped_test() ->
    {R, _T, _A} = rebuild([event(0, <<"roster_snapshotted">>, #{entries => [packed(1)], capacity => 8}),
                       event(1, <<"something_from_the_future">>, #{whatever => true})]),

    ?assertEqual(1, roster:depth(R)).

%% A genome that will not unpack costs one controller, never the boot.
a_corrupt_entry_costs_one_controller_test() ->
    Broken = maps:put(genome, <<"not a genome">>, packed(2)),
    {R, _T, _A} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), Broken], capacity => 8})]),

    ?assertEqual(1, roster:depth(R)).

%%==============================================================================
%% The tally: what the lineage has done, which never survived a deploy
%%==============================================================================

the_tally_rides_with_the_snapshot_test() ->
    Tally = #{rounds => 9000, tick => 12, raids => 4},
    {_R, T, _A} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [], capacity => 8, tally => Tally})]),

    ?assertEqual(Tally, T).

%% ⚠ EVERY SNAPSHOT WRITTEN BEFORE 2026-08-07 HAS NO TALLY, and an absent one is
%% not a tally of zero. It comes back empty and `island:with_tally/2' leaves the
%% live counters alone.
a_snapshot_without_a_tally_restores_an_empty_one_test() ->
    {_R, T, _A} = rebuild([event(0, <<"roster_snapshotted">>, #{entries => [], capacity => 8})]),

    ?assertEqual(#{}, T).

the_tally_follows_the_snapshot_that_replaced_it_test() ->
    {_R, T, _A} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [], capacity => 8, tally => #{rounds => 10}}),
                       event(1, <<"roster_snapshotted">>,
                             #{entries => [], capacity => 8, tally => #{rounds => 20}})]),

    ?assertEqual(#{rounds => 20}, T).

%% Nothing stored is a fresh island, not a crash.
an_empty_stream_restores_nothing_test() ->
    {R, T, _A} = rebuild([]),

    ?assertEqual(0, roster:depth(R)),
    ?assertEqual(#{}, T).

%%==============================================================================
%% The invader archive
%%==============================================================================

%% ⚠⚠ A RESTORED INVADER KEEPS THE TICK IT ARRIVED ON, AND THIS IS THE WHOLE
%% REASON THE ARCHIVE IS PERSISTED. Its eras are the age of each entry, so
%% witnessing them at the restore moment would date every one of them to the boot
%% and collapse every era into one. The archive would then say the island has only
%% ever faced things from this morning — which is exactly the blindness it exists
%% to remove, and it would look perfectly healthy while saying it.
a_restored_invader_keeps_the_era_it_arrived_in_test() ->
    Packed = #{id => <<"i1">>,
               genome => drone_genome:pack(genome(7)),
               from => <<"beam01">>,
               raid => <<"r1">>,
               seen_at => 40},

    {_R, _T, A} = rebuild([event(0, <<"roster_snapshotted">>,
                                 #{entries => [], capacity => 8,
                                   invaders => [Packed], invader_capacity => 16})]),

    ?assertEqual(1, invaders:depth(A)),
    ?assertEqual(16, invaders:capacity(A)),
    [E] = invaders:entries(A),
    ?assertEqual(40, invaders:entry_seen_at(E)),
    ?assertEqual(<<"beam01">>, invaders:entry_from(E)),
    %% And it is genuinely old at a later moment, rather than newly witnessed.
    %% `seen_at' is wall clock in milliseconds, so 40 ms in and an hour later is
    %% an age of about an hour: era 11 or 12.
    ?assert(invaders:era_of(E, 3_600_000) > 10).

%% ⚠ A SNAPSHOT WRITTEN BEFORE THE ARCHIVE EXISTED HAS NO `invaders' KEY. Islands
%% roll one at a time and a rollback must not be an outage, so that is an empty
%% archive rather than a crash — the same shape a fresh boot produces.
a_snapshot_from_before_the_archive_restores_an_empty_one_test() ->
    {_R, _T, A} = rebuild([event(0, <<"roster_snapshotted">>,
                                 #{entries => [], capacity => 8})]),
    ?assertEqual(0, invaders:depth(A)).

%% A corrupt genome costs one invader, not the archive.
a_corrupt_invader_costs_one_invader_test() ->
    Good = #{id => <<"i1">>, genome => drone_genome:pack(genome(7)),
             from => <<"beam01">>, raid => <<"r1">>, seen_at => 40},
    Bad = #{id => <<"i2">>, genome => <<"not a genome">>,
            from => <<"beam01">>, raid => <<"r1">>, seen_at => 41},

    {_R, _T, A} = rebuild([event(0, <<"roster_snapshotted">>,
                                 #{entries => [], capacity => 8,
                                   invaders => [Good, Bad]})]),
    ?assertEqual(1, invaders:depth(A)).

%%==============================================================================
%% The stream name, which nothing checked until it was changed
%%==============================================================================

%% ⚠ THE OBVIOUS EPOCH NAME DOES NOT PARSE, AND EVERY TEST IN THIS FILE WOULD HAVE
%% PASSED ANYWAY. They are built on fixtures shaped like store replies, so the
%% name is never handed to the store here. `$dronex:roster:g2' — the natural way
%% to write a second generation — is rejected by
%% `reckon_db_stream_path:stream_path/1', and this module's own header records
%% what that costs: the rejection arrives as an exit rather than a return,
%% `reckon_gater_retry' cannot match it against its non-retriable list, and it
%% retries eleven times with backoff for about four minutes inside the island
%% process. Five islands, on a deploy, over a colon.
the_stream_name_is_one_the_store_will_accept_test() ->
    %% ⚠ IT RETURNS THE BARE PATH ON SUCCESS AND A TAGGED TUPLE ON FAILURE, which
    %% is worth spelling out because the asymmetry cost a red test here: a probe
    %% written to check this wrapped its own result in `{ok, _}' and made the
    %% success case look tagged too.
    ?assertMatch([streams, _, _],
                 reckon_db_stream_path:stream_path(roster_log:stream())),
    %% And stated the other way round, so this test cannot pass by the parser
    %% having been made permissive.
    %%
    %% ⚠⚠ IT RAISES RATHER THAN RETURNING AN ERROR, WHICH IS THE WHOLE REASON A
    %% BAD NAME IS EXPENSIVE INSTEAD OF LOUD. A returned `{error, _}' would be
    %% matched by `reckon_gater_retry' against its non-retriable list and dropped
    %% immediately. An exit is not matchable there, so it is treated as a
    %% transient fault and retried eleven times with backoff, about four minutes,
    %% inside the island process. Asserting the RAISE rather than a return value
    %% is therefore the point of this half.
    ?assertError({invalid_stream_id, _},
                 reckon_db_stream_path:stream_path(<<"$dronex:roster:g2">>)).

%% ⚠⚠ AND IT IS NOT A PRE-WIPE STREAM. On 2026-08-09 the fleet was wiped by
%% starting a new lineage rather than deleting a store: the physics changed
%% underneath every genome bred so far, so their fitness was earned in a different
%% game. Pointing this back at `$dronex:roster' silently resurrects all of it, on
%% every island, at the next boot.
%%
%% ⚠⚠⚠ AND EVERY SUPERSEDED NAME IS LISTED, NOT JUST THE FIRST, BECAUSE THIS TEST
%% COULD NOT SEE THE SECOND WIPE OR THE THIRD. It asserted only that the stream
%% was not `$dronex:roster', so it passed identically on `_g2', `_g3' and `_g4' —
%% including on a revert from `_g4' to `_g3', which is the failure that can
%% actually happen now. There have been three wipes in two days and each one
%% makes the previous name a hazard rather than a spare.
%%
%% A revert is not hypothetical: the name is one token, it reads like a version
%% nobody needs to think about, and the whole cost of getting it wrong is invisible
%% — the island boots, restores a roster bred under other physics, and reports
%% itself healthy while its fitness numbers mean something else.
the_lineage_is_not_one_bred_under_older_physics_test() ->
    Superseded = [<<"$dronex:roster">>, <<"$dronex:roster_g2">>,
                  <<"$dronex:roster_g3">>],
    [?assertNotEqual(Old, roster_log:stream()) || Old <- Superseded].
