%% @doc A name is not an identity, and the four things that break when they are
%% confused are worth a test each.
-module(dronex_identity_tests).

-include_lib("eunit/include/eunit.hrl").

the_name_is_typed_and_defaults_to_the_hostname_test() ->
    Was = os:getenv("HECATE_DRONEX_ISLAND"),
    true = os:unsetenv("HECATE_DRONEX_ISLAND"),
    {ok, Host} = inet:gethostname(),
    ?assertEqual(list_to_binary(Host), dronex_identity:island()),
    true = os:putenv("HECATE_DRONEX_ISLAND", "  beam02  "),
    ?assertEqual(<<"beam02">>, dronex_identity:island()),
    restore("HECATE_DRONEX_ISLAND", Was).

the_identity_is_128_bits_of_hex_test() ->
    Id = in_fresh_dir(fun dronex_identity:island_id/0),
    ?assertEqual(32, byte_size(Id)),
    ?assertMatch({match, _}, re:run(Id, "^[0-9a-f]{32}$")).

%% Stable across reads, because a fact goes out on a timer and this must not
%% become a file read per publish.
the_identity_is_stable_within_a_node_test() ->
    {A, B} = in_fresh_dir(fun () ->
                                  X = dronex_identity:island_id(),
                                  Y = dronex_identity:island_id(),
                                  {X, Y}
                          end),
    ?assertEqual(A, B).

%% ⚠ THE ONE THAT MATTERS ON A FLEET. The bind mount is what makes an island the
%% same island after a container recreate. This is that property, tested: mint,
%% forget everything in memory, read again from the same directory.
the_identity_survives_a_restart_of_the_node_test() ->
    Dir = fresh_dir("survives"),
    First = in_dir(Dir, fun dronex_identity:island_id/0),
    Second = in_dir(Dir, fun dronex_identity:island_id/0),
    ?assertEqual(First, Second).

%% ⚠ AND TWO ISLANDS ARE TWO ISLANDS. Different directories, different identity,
%% however they are named. This is what stops a spectator merging them.
two_islands_do_not_collide_however_they_are_named_test() ->
    Was = os:getenv("HECATE_DRONEX_ISLAND"),
    true = os:putenv("HECATE_DRONEX_ISLAND", "beam01"),
    A = in_dir(fresh_dir("collide_a"), fun dronex_identity:island_id/0),
    B = in_dir(fresh_dir("collide_b"), fun dronex_identity:island_id/0),
    ?assertNotEqual(A, B),
    restore("HECATE_DRONEX_ISLAND", Was).

%% A write torn by a crash would otherwise give this island a blank identity for
%% ever, which is the collision the whole module exists to prevent.
a_torn_identity_file_is_reminted_test() ->
    Dir = fresh_dir("torn"),
    Path = filename:join(Dir, "island.id"),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, <<"half">>),
    Id = in_dir(Dir, fun dronex_identity:island_id/0),
    ?assertEqual(32, byte_size(Id)).

%%==============================================================================

fresh_dir(Name) ->
    Dir = filename:join(["/tmp", "dronex_identity_tests", Name]),
    _ = file:del_dir_r(Dir),
    Dir.

in_fresh_dir(Fun) -> in_dir(fresh_dir("default"), Fun).

%% Forgetting the persistent_term is what makes this a restart rather than a
%% second read: the module remembers, deliberately, so a test that did not forget
%% would be asserting the cache rather than the file.
in_dir(Dir, Fun) ->
    Was = os:getenv("HECATE_DRONEX_DATA_DIR"),
    true = os:putenv("HECATE_DRONEX_DATA_DIR", Dir),
    persistent_term:erase({dronex_identity, island_id}),
    Result = Fun(),
    persistent_term:erase({dronex_identity, island_id}),
    restore("HECATE_DRONEX_DATA_DIR", Was),
    Result.

restore(Name, false) -> os:unsetenv(Name), ok;
restore(Name, Value) -> os:putenv(Name, Value), ok.
