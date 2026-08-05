%% @doc The transport boundary, tested where it fails rather than where it works.
%%
%% There is no mesh under eunit, which makes this the ideal place to test the
%% failure paths: every one of them is the live path here.
-module(dronex_mesh_tests).

-include_lib("eunit/include/eunit.hrl").

%% ⚠ THE ONE THAT KEEPS AN ISLAND ALIVE. `hecate_om_identity:macula_client/0' is
%% a gen_server call, so with hecate_om down it does not return an error, it
%% EXITS with noproc. Unwrapped, that exit travels up through the publish timer
%% and kills the island, losing the roster it was holding.
%%
%% Verified to go red without the wrapper: removing the try/catch in
%% `dronex_mesh:endpoint/0' turns this from a returned tuple into an exit.
a_publish_with_no_mesh_is_an_error_and_not_an_exit_test() ->
    ?assertMatch({error, _}, dronex_mesh:publish(<<"dronex/vitals">>, #{a => 1})).

a_door_that_cannot_be_read_is_an_error_and_not_an_exit_test() ->
    ?assertMatch({error, _}, dronex_mesh:station()).

availability_is_false_rather_than_a_crash_test() ->
    ?assertEqual(false, dronex_mesh:available()).

%% Unset falls back, so a deployment that has not been told about the public
%% realm keeps behaving as it did rather than going silent.
an_unset_realm_falls_back_to_the_fleet_one_test() ->
    Was = os:getenv("HECATE_DRONEX_REALM"),
    true = os:unsetenv("HECATE_DRONEX_REALM"),
    Fleet = <<1:256>>,
    ?assertEqual({ok, Fleet}, dronex_mesh:publish_realm(Fleet)),
    restore("HECATE_DRONEX_REALM", Was).

the_public_realm_decodes_from_hex_test() ->
    Was = os:getenv("HECATE_DRONEX_REALM"),
    Hex = "686fbbf84c5c33455764f4c07c642bd1b79ef4efc78455f61ac12936ca3bffe3",
    true = os:putenv("HECATE_DRONEX_REALM", Hex),
    {ok, Tag} = dronex_mesh:publish_realm(<<1:256>>),
    ?assertEqual(32, byte_size(Tag)),
    ?assertEqual(crypto:hash(sha256, <<"net.beamcampus.dronex">>), Tag),
    restore("HECATE_DRONEX_REALM", Was).

%% ⚠ A MALFORMED TAG IS AN ERROR RATHER THAN A FALLBACK, and this is the test
%% that says so. Falling back on a typo would publish public facts onto the
%% OPERATIONAL realm and report success, which is the one outcome nobody would
%% notice.
a_malformed_realm_refuses_rather_than_falling_back_test() ->
    Was = os:getenv("HECATE_DRONEX_REALM"),
    true = os:putenv("HECATE_DRONEX_REALM", "not-a-realm"),
    ?assertEqual({error, dronex_realm_not_64_hex}, dronex_mesh:publish_realm(<<1:256>>)),
    true = os:putenv("HECATE_DRONEX_REALM", lists:duplicate(64, $z)),
    ?assertEqual({error, dronex_realm_not_hex}, dronex_mesh:publish_realm(<<1:256>>)),
    restore("HECATE_DRONEX_REALM", Was).

%%==============================================================================

restore(Name, false) -> os:unsetenv(Name), ok;
restore(Name, Value) -> os:putenv(Name, Value), ok.
