%% @doc The store boundary, and the guard that would have caught the wedge.
-module(roster_log_writer_tests).

-include_lib("eunit/include/eunit.hrl").

%%==============================================================================
%% ⚠ THE ONE THAT MATTERS
%%==============================================================================

%% ⚠ THE STREAM ID IS A CONTRACT WITH ANOTHER LIBRARY AND IT WAS NEVER CHECKED.
%% `roster_log' shipped with the stream id `roster' and nothing in this
%% repository disagreed, because nothing here knew what reckon-db accepts. It
%% found out on a fleet node, twenty minutes after the first deploy, by wedging
%% the island for four minutes.
%%
%% This asks the library's OWN validator rather than restating its rule, so the
%% day reckon-gater tightens the format again this test fails here instead of in
%% production.
the_stream_id_is_one_reckon_db_will_accept_test() ->
    ?assert(reckon_gater_stream_id:is_valid(roster_log:stream())),
    ?assertEqual(ok, element(1, {ok, reckon_gater_stream_id:validate(roster_log:stream())})),
    %% System, not user: a singleton per store needs no 128 bits of identity.
    ?assert(reckon_gater_stream_id:is_system(roster_log:stream())).

%% And the check can find something: the id that was actually shipped fails it.
the_check_can_actually_find_something_test() ->
    ?assertNot(reckon_gater_stream_id:is_valid(<<"roster">>)),
    ?assertNot(reckon_gater_stream_id:is_valid(<<"$dronex-roster">>)),
    ?assertNot(reckon_gater_stream_id:is_valid(<<"Dronex:roster">>)).

%%==============================================================================
%% The writer
%%==============================================================================

writer_test_() ->
    {setup,
     fun () -> {ok, P} = roster_log_writer:start_link(), P end,
     fun (P) -> gen_server:stop(P) end,
     [fun a_fresh_writer_has_written_nothing_and_says_so/0,
      fun the_call_returns_before_the_write/0]}.

%% CHARTER.md rule 4: zeros go out from the first fact, so a writer that has
%% never written and a writer that is not reporting look different.
a_fresh_writer_has_written_nothing_and_says_so() ->
    ?assertEqual(#{written => 0, failed => 0, dropped => 0}, roster_log_writer:stats()).

%% ⚠ THE POINT OF THE WHOLE MODULE. The island must get its call back whether or
%% not there is a store, and here there is none: the cast returns, the writer
%% counts a failure rather than dying, and nothing blocks.
the_call_returns_before_the_write() ->
    R = roster:new(probe),
    ?assertEqual(ok, roster_log_writer:snapshot(no_such_store, R)),
    ?assertEqual(ok, roster_log_writer:snapshot(no_such_store, R)),
    %% stats/0 is a call, so it lands behind both casts and their writes: by the
    %% time it answers, the writer has finished with them.
    #{written := W, failed := F, dropped := D} = roster_log_writer:stats(),
    ?assertEqual(2, W + F + D),
    %% With no store the writes fail, and a failure is counted rather than fatal.
    ?assert(F > 0).
