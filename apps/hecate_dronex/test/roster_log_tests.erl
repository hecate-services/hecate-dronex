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
    {R, _T} = rebuild([event(0, <<"roster_snapshotted">>,
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
    {R, _T} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), packed(2)], capacity => 8}),
                       event(1, <<"roster_snapshotted">>,
                             #{entries => [packed(3)], capacity => 8})]),

    ?assertEqual(1, roster:depth(R)).

the_tail_after_a_snapshot_is_replayed_test() ->
    {R, _T} = rebuild([event(0, <<"roster_snapshotted">>, #{entries => [packed(1)], capacity => 8}),
                       event(1, <<"genome_admitted">>, packed(2)),
                       event(2, <<"genome_admitted">>, packed(3))]),

    ?assertEqual(3, roster:depth(R)).

an_eviction_in_the_tail_is_replayed_test() ->
    Gone = maps:get(id, packed(1)),
    {R, _T} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), packed(2)], capacity => 8}),
                       event(1, <<"genome_evicted">>, #{id => Gone})]),

    ?assertEqual(1, roster:depth(R)),
    ?assertNot(roster:has(R, Gone)).

%% An event type written by a later image must not stop an older one booting: a
%% rollback that refuses to start is an outage, and the cost of skipping is a
%% roster that is visibly shallower.
an_unknown_event_type_is_skipped_test() ->
    {R, _T} = rebuild([event(0, <<"roster_snapshotted">>, #{entries => [packed(1)], capacity => 8}),
                       event(1, <<"something_from_the_future">>, #{whatever => true})]),

    ?assertEqual(1, roster:depth(R)).

%% A genome that will not unpack costs one controller, never the boot.
a_corrupt_entry_costs_one_controller_test() ->
    Broken = maps:put(genome, <<"not a genome">>, packed(2)),
    {R, _T} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [packed(1), Broken], capacity => 8})]),

    ?assertEqual(1, roster:depth(R)).

%%==============================================================================
%% The tally: what the lineage has done, which never survived a deploy
%%==============================================================================

the_tally_rides_with_the_snapshot_test() ->
    Tally = #{rounds => 9000, tick => 12, raids => 4},
    {_R, T} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [], capacity => 8, tally => Tally})]),

    ?assertEqual(Tally, T).

%% ⚠ EVERY SNAPSHOT WRITTEN BEFORE 2026-08-07 HAS NO TALLY, and an absent one is
%% not a tally of zero. It comes back empty and `island:with_tally/2' leaves the
%% live counters alone.
a_snapshot_without_a_tally_restores_an_empty_one_test() ->
    {_R, T} = rebuild([event(0, <<"roster_snapshotted">>, #{entries => [], capacity => 8})]),

    ?assertEqual(#{}, T).

the_tally_follows_the_snapshot_that_replaced_it_test() ->
    {_R, T} = rebuild([event(0, <<"roster_snapshotted">>,
                             #{entries => [], capacity => 8, tally => #{rounds => 10}}),
                       event(1, <<"roster_snapshotted">>,
                             #{entries => [], capacity => 8, tally => #{rounds => 20}})]),

    ?assertEqual(#{rounds => 20}, T).

%% Nothing stored is a fresh island, not a crash.
an_empty_stream_restores_nothing_test() ->
    {R, T} = rebuild([]),

    ?assertEqual(0, roster:depth(R)),
    ?assertEqual(#{}, T).
