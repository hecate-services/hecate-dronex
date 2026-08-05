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

only_what_exists_is_published_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{})) end),
    Keys = lists:sort(maps:keys(Fact)),
    ?assertEqual([capacity, fact_version, island, island_id, roster,
                  station_connected, station_host, station_id, tick], Keys).

%% ⚠ CHARTER.md rule 4. An island with an empty roster and an island that does
%% not report a roster look identical unless the zero goes out.
the_empty_roster_is_reported_rather_than_omitted_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{})) end),
    ?assertEqual(0, maps:get(roster, Fact)),
    ?assertEqual(240, maps:get(capacity, Fact)).

the_tick_is_on_every_fact_test() ->
    I = island:run(island:new(#{}), 7),
    Fact = with_data_dir(fun () -> dronex_facts:vitals(I) end),
    ?assertEqual(7, maps:get(tick, Fact)).

%% ⚠ A DOOR THAT CANNOT BE READ IS REPORTED, NOT OMITTED. A key that appears only
%% sometimes is a field a chart silently drops. There is no mesh under eunit, so
%% this is the unreachable branch and it is the one that must not vanish.
a_dark_mesh_still_reports_a_door_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{})) end),
    ?assertEqual(<<"unknown">>, maps:get(station_host, Fact)),
    ?assertEqual(false, maps:get(station_connected, Fact)),
    ?assertEqual(<<>>, maps:get(station_id, Fact)).

%% ⚠ ATOM KEYS ONLY, AND NO TUPLES AS VALUES. An atom key and a binary key of the
%% same name collide into one on the wire, and a tuple does not survive the
%% encoder cleanly. This walks the whole fact rather than trusting the author.
the_wire_rules_hold_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{})) end),
    maps:foreach(
      fun (K, V) ->
              ?assert(is_atom(K)),
              ?assertNot(is_tuple(V))
      end, Fact).

fact_version_is_on_the_fact_test() ->
    Fact = with_data_dir(fun () -> dronex_facts:vitals(island:new(#{})) end),
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
