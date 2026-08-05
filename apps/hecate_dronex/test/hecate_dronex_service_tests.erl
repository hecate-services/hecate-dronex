%% @doc The service contract, checked at compile time rather than at boot.
%%
%% ⚠ WHY THIS EXISTS. `hecate_om:boot/1' calls all six callbacks during startup,
%% so a missing export fails with `undef' against the live mesh on a fleet node
%% and not at compile time. Two sibling services learned that the expensive way.
-module(hecate_dronex_service_tests).

-include_lib("eunit/include/eunit.hrl").

the_six_callbacks_are_exported_test() ->
    _ = code:ensure_loaded(hecate_dronex_service),
    Exports = hecate_dronex_service:module_info(exports),
    [?assert(lists:member(F, Exports))
     || F <- [{info, 0}, {start, 1}, {stop, 1},
              {health, 0}, {capabilities, 0}, {identity_spec, 0}]].

%% Exporting these two is what makes hecate_om open a store. They are asserted
%% present because `config/sys.config.src' carries an `evoq' block that is only
%% mandatory while they exist: if they were ever dropped, that block would become
%% dead configuration nobody could explain.
the_store_callbacks_are_exported_test() ->
    Exports = hecate_dronex_service:module_info(exports),
    ?assert(lists:member({store_id, 0}, Exports)),
    ?assert(lists:member({data_dir, 0}, Exports)).

%% ⚠ THE GUARD FOR THE BOOT CRASH THAT TOOK DOWN TWO OF THREE FLEET NODES ON A
%% SIBLING. `store_id/0' being exported means evoq must be configured, and evoq
%% starts before any service code runs, so nothing can inject it later. This
%% asserts the two agree, in the only place both are visible.
%%
%% It reads the file rather than the application env, because at eunit time the
%% release has not been assembled and `sys.config.src' is still a template.
the_evoq_block_names_the_same_store_test() ->
    Src = read_sys_config_src(),
    ?assert(string:find(Src, "{evoq,") =/= nomatch),
    Named = atom_to_list(hecate_dronex_service:store_id()),
    ?assert(string:find(Src, "{store_id,") =/= nomatch),
    ?assertNotEqual(nomatch, string:find(Src, Named)).

the_health_endpoint_is_green_when_up_test() ->
    ?assertEqual(ok, hecate_dronex_service:health()).

%% A capability is a promise that something answers when another island calls it.
%% Nothing here answers anything yet, so the list is empty, and this test is what
%% makes growing it a deliberate act rather than a drift.
nothing_is_advertised_yet_test() ->
    ?assertEqual([], hecate_dronex_service:capabilities()).

%% ⚠ AUTHORITY IN TWO PLACES IS AUTHORITY THAT DRIFTS. A sibling quietly
%% published on two topics its identity spec did not name. This is the guard.
the_identity_spec_asks_for_exactly_the_topics_published_test() ->
    #{resources := Asked} = hecate_dronex_service:identity_spec(),
    ?assertEqual(lists:sort(dronex_facts:topics()), lists:sort(Asked)).

the_data_dir_falls_back_rather_than_crashing_test() ->
    Was = os:getenv("HECATE_DRONEX_DATA_DIR"),
    true = os:unsetenv("HECATE_DRONEX_DATA_DIR"),
    ?assertEqual("/tmp/hecate_dronex", hecate_dronex_service:data_dir()),
    true = os:putenv("HECATE_DRONEX_DATA_DIR", "/bulk0/dronex"),
    ?assertEqual("/bulk0/dronex", hecate_dronex_service:data_dir()),
    restore("HECATE_DRONEX_DATA_DIR", Was).

%%==============================================================================

restore(Name, false) -> os:unsetenv(Name), ok;
restore(Name, Value) -> os:putenv(Name, Value), ok.

read_sys_config_src() ->
    Path = filename:join([code:lib_dir(hecate_dronex), "..", "..", "..", "..",
                          "config", "sys.config.src"]),
    {ok, Bin} = file:read_file(Path),
    binary_to_list(Bin).
