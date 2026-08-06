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
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    Keys = lists:sort(maps:keys(Fact)),
    ?assertEqual([ablation_delta_air, ablation_delta_all, ablation_delta_ground,
                  ablation_void, ablations, admissions, advertising,
                  benchmark_draws, benchmark_losses, benchmark_rungs,
                  benchmark_sitter,
                  benchmark_starts, benchmark_wins, capacity, captures, defences,
                  fact_version, generation, island, island_id, listening, open,
                  raids, raids_home, raids_lost, roster,
                  roster_write_failures, roster_writes, roster_writes_dropped,
                  rounds, signal_entropy, signal_volume,
                  station_connected, station_host, station_id, tick], Keys).

%% ⚠ MANY RAIDS AND ZERO CAPTURES IS A DIFFERENT WORLD FROM NO RAIDS AT ALL, and
%% from the outside they look the same if only one number goes out. An island
%% refusing every incoming raid on an engine mismatch is busy, healthy, and not
%% participating in the one idea the repository is named after.
an_island_that_has_never_raided_publishes_zeros_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    [?assertEqual(0, maps:get(K, Fact))
     || K <- [raids, raids_home, raids_lost, defences, captures]].

%% ⚠ A RAID IS THE ONLY FACT HERE THAT IS ABOUT TWO ISLANDS. A reader filing
%% facts under the publisher would file this under the defender alone, and the
%% attacker's half of the story would have no home, so both identities travel.
a_raid_fact_names_both_islands_test() ->
    Meta = #{from => <<"them">>, raid => <<"r1">>, tick => 9,
             defenders => 4, defenders_home => 3},
    Result = #{winner => defender, ticks => 40, survivors => [], withdrawn => [],
               signal_volume => 0, frames => []},
    Fact = with_data_dir(fun () ->
        dronex_facts:raid(Result, [{<<"g1">>, survived}, {<<"g2">>, lost}], Meta)
    end),
    ?assertEqual(<<"them">>, maps:get(attacker_id, Fact)),
    ?assertEqual(dronex_identity:island_id(), maps:get(island_id, Fact)),
    ?assertEqual(<<"r1">>, maps:get(raid_id, Fact)),
    ?assertEqual(2, maps:get(raiders, Fact)),
    ?assertEqual(1, maps:get(raiders_home, Fact)),
    %% ⚠ BOTH SIDES OF THE LEDGER. Only the attacker's losses were published at
    %% first, so a reader could see what a raid cost the raider and not what it
    %% cost the island that beat it. Both pay on the same terms, and a score
    %% showing one of them is not a score.
    ?assertEqual(4, maps:get(defenders, Fact)),
    ?assertEqual(3, maps:get(defenders_home, Fact)),
    %% It carries the recording, like a bout, because a raid is worth watching.
    ?assertEqual(raid, maps:get(kind, Fact)).

%% The topic exists because something publishes it now, which is the rule the
%% topic list has followed since item 1.
the_raid_topic_is_published_and_authorised_test() ->
    ?assert(lists:member(dronex_facts:topic(raid), dronex_facts:topics())),
    #{resources := Asked} = hecate_dronex_service:identity_spec(),
    ?assert(lists:member(dronex_facts:topic(raid), Asked)).

%% ⚠ WHETHER THE LINEAGE IS BEING SAVED IS ON THE WIRE, because the first
%% deployed island was not saving it and looked healthy for four minutes.
whether_the_roster_is_being_written_is_published_test() ->
    Fact = with_data_dir(fun () ->
        dronex_facts:vitals(island:new(#{}),
                            (runtime())#{writer => #{written => 3, failed => 1, dropped => 7}})
    end),
    ?assertEqual(3, maps:get(roster_writes, Fact)),
    ?assertEqual(1, maps:get(roster_write_failures, Fact)),
    ?assertEqual(7, maps:get(roster_writes_dropped, Fact)).

%% ⚠ AN ISLAND THAT HAS NEVER ABLATED PUBLISHES ZEROS WITH A ZERO COUNT, and that
%% is the whole reason `ablations' exists. Without it a delta of zero from an
%% instrument that has never run is indistinguishable from a delta of zero from a
%% channel nobody depends on, and those are opposite conclusions.
a_never_ablated_island_says_so_rather_than_reporting_a_zero_delta_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertEqual(0, maps:get(ablations, Fact)),
    ?assert(maps:get(ablation_void, Fact)),
    ?assertEqual(0, maps:get(signal_volume, Fact)),
    ?assertEqual(0, maps:get(signal_entropy, Fact)).

%% And once it has, the count rises and the report is the one it measured.
%% ⚠ AN ISLAND THAT CANNOT BE RAIDED LOOKS HEALTHY FROM EVERY OTHER ANGLE. It
%% breeds, publishes, answers /health, hears its neighbours and raids them. The
%% only symptom is somebody else's counter not moving, on another machine.
whether_the_island_can_be_raided_at_all_is_published_test() ->
    Dark = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertNot(maps:get(advertising, Dark)),
    ?assertNot(maps:get(listening, Dark)),

    Live = with_data_dir(fun () ->
        dronex_facts:vitals(island:new(#{}),
                            (runtime())#{advertising => true, listening => true})
    end),
    ?assert(maps:get(advertising, Live)),
    ?assert(maps:get(listening, Live)).

an_ablated_island_publishes_the_measurement_test() ->
    Report = ablation:measure([]),
    I = island:ablated(island:new(#{}), Report#{volume := 12, void := false}),
    Fact = with_data_dir(fun () -> dronex_facts:vitals(I, runtime()) end),
    ?assertEqual(1, maps:get(ablations, Fact)),
    ?assertNot(maps:get(ablation_void, Fact)),
    ?assertEqual(12, maps:get(signal_volume, Fact)).

%% ⚠ CHARTER.md rule 4. An island with an empty roster and an island that does
%% not report a roster look identical unless the zero goes out.
the_empty_roster_is_reported_rather_than_omitted_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertEqual(0, maps:get(roster, Fact)),
    ?assertEqual(240, maps:get(capacity, Fact)).

the_tick_is_on_every_fact_test() ->
    I = island:run(island:new(#{}), 7),
    Fact = with_data_dir(fun () -> dronex_facts:vitals(I, runtime()) end),
    ?assertEqual(7, maps:get(tick, Fact)).

%% ⚠ A DOOR THAT CANNOT BE READ IS REPORTED, NOT OMITTED. A key that appears only
%% sometimes is a field a chart silently drops. There is no mesh under eunit, so
%% this is the unreachable branch and it is the one that must not vanish.
a_dark_mesh_still_reports_a_door_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertEqual(<<"unknown">>, maps:get(station_host, Fact)),
    ?assertEqual(false, maps:get(station_connected, Fact)),
    ?assertEqual(<<>>, maps:get(station_id, Fact)).

%% ⚠ ATOM KEYS ONLY, AND NO TUPLES AS VALUES. An atom key and a binary key of the
%% same name collide into one on the wire, and a tuple does not survive the
%% encoder cleanly. This walks the whole fact rather than trusting the author.
the_wire_rules_hold_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    maps:foreach(
      fun (K, V) ->
              ?assert(is_atom(K)),
              ?assertNot(is_tuple(V))
      end, Fact).

fact_version_is_on_the_fact_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
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

%% The server's view of itself before anything has happened: nothing written,
%% and not yet reachable. Zeros and falses rather than absent fields, so a reader
%% can tell `nothing yet' from `not reporting'.
runtime() ->
    #{writer => roster_log_writer:silent(), advertising => false,
      listening => false, open => false}.

%%==============================================================================
%% Availability, which is the only thing islands tell each other
%%==============================================================================

%% ⚠ THE TWO EXTRA FIELDS EACH TURN A WASTED RAID INTO A FILTER. An incompatible
%% ENGINE would refuse on arrival and an island at its ROSTER floor would have
%% nobody to field, and both cost a whole raiding party to discover.
an_opening_carries_what_a_caller_needs_to_skip_a_pointless_raid_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:opened(island:new(#{})) end),
    ?assertEqual(lists:sort([fact_version, fingerprint, island, island_id, roster]),
                 lists:sort(maps:keys(Fact))),
    ?assertEqual(dronex_raid:fingerprint(), maps:get(fingerprint, Fact)),
    ?assertEqual(0, maps:get(roster, Fact)).

%% Closing says only who, because the listener needs nothing else to forget you.
a_closing_says_only_who_test() ->
    Fact = with_data_dir(fun dronex_facts:closed/0),
    ?assertEqual(lists:sort([fact_version, island, island_id]),
                 lists:sort(maps:keys(Fact))).

%% ⚠ PRESENCE STAYS ON VITALS AND AVAILABILITY IS ITS OWN TOPIC, because the site
%% needs the islands that are CLOSED. Deriving presence from the opening topic
%% would draw the combatants and quietly omit everyone who chose not to fight.
availability_is_separate_from_presence_test() ->
    ?assert(lists:member(dronex_facts:topic(opened), dronex_facts:topics())),
    ?assert(lists:member(dronex_facts:topic(closed), dronex_facts:topics())),
    ?assertNotEqual(dronex_facts:topic(opened), dronex_facts:topic(vitals)),
    #{resources := Asked} = hecate_dronex_service:identity_spec(),
    [?assert(lists:member(T, Asked)) || T <- dronex_facts:topics()].

%% And the site can tell a turtling island from a fighting one without
%% subscribing to the availability topics at all.
whether_an_island_is_open_is_on_vitals_too_test() ->
    Shut = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{}), runtime()) end),
    ?assertNot(maps:get(open, Shut)),
    Open = with_data_dir(fun () ->
        dronex_facts:vitals(island:new(#{}), (runtime())#{open => true})
    end),
    ?assert(maps:get(open, Open)).

%% ⚠ THE SAME FLOOR THE ATTACKER RESPECTS. An island that has been ground down
%% stops being able to attack and stops being worth attacking at the same moment,
%% which is one rule rather than two that could disagree.
an_island_at_its_floor_cannot_defend_test() ->
    {R, _} = trainer:seed_roster(roster:new(p, 240), raid:floor_of() + raid:party(),
                                 rand:seed_s(exsss, {2, 4, 6})),
    I = island:with_roster(island:new(#{}), R),
    ?assert(island:can_defend(I, raid:party())),
    ?assertNot(island:can_defend(I, raid:party() + 1)),
    ?assertNot(island:can_defend(island:new(#{}), raid:party())).
