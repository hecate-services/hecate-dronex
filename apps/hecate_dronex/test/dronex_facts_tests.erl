%% @doc What an island says about itself, checked as a shape.
-module(dronex_facts_tests).

-include_lib("eunit/include/eunit.hrl").

topics_are_namespaced_test() ->
    Was = os:getenv("HECATE_DRONEX_NS"),
    true = os:unsetenv("HECATE_DRONEX_NS"),
    ?assertEqual(<<"dronex/vitals">>, dronex_facts:topic(vitals)),
    true = os:putenv("HECATE_DRONEX_NS", "laptop"),
    ?assertEqual(<<"laptop/vitals">>, dronex_facts:topic(vitals)),
    restore("HECATE_DRONEX_NS", Was).

%% ⚠ THE NAMESPACE SEPARATES DEPLOYMENTS AND NEVER ISLANDS. One topic carries
%% every island and the payload says which. This asserts the id is not in the
%% topic, because putting it there is the mistake that scales worst.
the_island_id_is_never_in_a_topic_test() ->
    Id = with_data_dir(fun dronex_identity:island_id/0),
    [?assertEqual(nomatch, binary:match(T, Id)) || T <- dronex_facts:topics()].

%% ⚠ THE KEY LIST IS EXHAUSTIVE ON PURPOSE, so a field cannot be added to the
%% wire without somebody deciding it means something. `dronex_facts' refuses to
%% publish what does not exist yet, and this is the guard on that refusal.
only_what_exists_is_published_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), writer()) end),
    Keys = lists:sort(maps:keys(Fact)),
    ?assertEqual([ablation_delta_air, ablation_delta_all, ablation_delta_ground,
                  ablation_void, ablations, admissions,
                  benchmark_draws, benchmark_losses, benchmark_rungs,
                  benchmark_starts, benchmark_wins, capacity, fact_version,
                  generation, island, island_id, roster,
                  roster_write_failures, roster_writes, roster_writes_dropped,
                  rounds, signal_entropy, signal_volume,
                  station_connected, station_host, station_id, tick], Keys).

%% ⚠ WHETHER THE LINEAGE IS BEING SAVED IS ON THE WIRE, because the first
%% deployed island was not saving it and looked healthy for four minutes.
whether_the_roster_is_being_written_is_published_test() ->
    Fact = with_data_dir(fun () ->
        dronex_facts:vitals(island:new(#{}), #{written => 3, failed => 1, dropped => 7})
    end),
    ?assertEqual(3, maps:get(roster_writes, Fact)),
    ?assertEqual(1, maps:get(roster_write_failures, Fact)),
    ?assertEqual(7, maps:get(roster_writes_dropped, Fact)).

%% ⚠ AN ISLAND THAT HAS NEVER ABLATED PUBLISHES ZEROS WITH A ZERO COUNT, and that
%% is the whole reason `ablations' exists. Without it a delta of zero from an
%% instrument that has never run is indistinguishable from a delta of zero from a
%% channel nobody depends on, and those are opposite conclusions.
a_never_ablated_island_says_so_rather_than_reporting_a_zero_delta_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), writer()) end),
    ?assertEqual(0, maps:get(ablations, Fact)),
    ?assert(maps:get(ablation_void, Fact)),
    ?assertEqual(0, maps:get(signal_volume, Fact)),
    ?assertEqual(0, maps:get(signal_entropy, Fact)).

%% And once it has, the count rises and the report is the one it measured.
an_ablated_island_publishes_the_measurement_test() ->
    Report = ablation:measure([]),
    I = island:ablated(island:new(#{}), Report#{volume := 12, void := false}),
    Fact = with_data_dir(fun () -> dronex_facts:vitals(I, writer()) end),
    ?assertEqual(1, maps:get(ablations, Fact)),
    ?assertNot(maps:get(ablation_void, Fact)),
    ?assertEqual(12, maps:get(signal_volume, Fact)).

%% ⚠ CHARTER.md rule 4. An island with an empty roster and an island that does
%% not report a roster look identical unless the zero goes out.
the_empty_roster_is_reported_rather_than_omitted_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), writer()) end),
    ?assertEqual(0, maps:get(roster, Fact)),
    ?assertEqual(240, maps:get(capacity, Fact)).

the_tick_is_on_every_fact_test() ->
    I = island:run(island:new(#{}), 7),
    Fact = with_data_dir(fun () -> dronex_facts:vitals(I, writer()) end),
    ?assertEqual(7, maps:get(tick, Fact)).

%% ⚠ A DOOR THAT CANNOT BE READ IS REPORTED, NOT OMITTED. A key that appears only
%% sometimes is a field a chart silently drops. There is no mesh under eunit, so
%% this is the unreachable branch and it is the one that must not vanish.
a_dark_mesh_still_reports_a_door_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), writer()) end),
    ?assertEqual(<<"unknown">>, maps:get(station_host, Fact)),
    ?assertEqual(false, maps:get(station_connected, Fact)),
    ?assertEqual(<<>>, maps:get(station_id, Fact)).

%% ⚠ ATOM KEYS ONLY, AND NO TUPLES AS VALUES. An atom key and a binary key of the
%% same name collide into one on the wire, and a tuple does not survive the
%% encoder cleanly. This walks the whole fact rather than trusting the author.
the_wire_rules_hold_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), writer()) end),
    maps:foreach(
      fun (K, V) ->
              ?assert(is_atom(K)),
              ?assertNot(is_tuple(V))
      end, Fact).

fact_version_is_on_the_fact_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), writer()) end),
    ?assertEqual(dronex_facts:fact_version(), maps:get(fact_version, Fact)).

%%==============================================================================

%% The identity is minted into the data directory, so every test that reaches it
%% needs one it may write to.
with_data_dir(Fun) ->
    Was = os:getenv("HECATE_DRONEX_DATA_DIR"),
    Dir = filename:join("/tmp", "dronex_facts_tests"),
    true = os:putenv("HECATE_DRONEX_DATA_DIR", Dir),
    persistent_term:erase({dronex_identity, island_id}),
    Result = Fun(),
    restore("HECATE_DRONEX_DATA_DIR", Was),
    Result.

restore(Name, false) -> os:unsetenv(Name), ok;
restore(Name, Value) -> os:putenv(Name, Value), ok.

%% A writer that has not spoken yet. Zeros rather than an absent field, so a
%% reader can tell `nothing written' from `not reporting'.
writer() -> roster_log_writer:silent().
