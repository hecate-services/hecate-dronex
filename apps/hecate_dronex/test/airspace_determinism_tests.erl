%% @doc The match path holds no clock, no generator and no libm. STRUCTURAL.
%%
%% ⚠ WHY THIS IS A CALL-GRAPH CHECK AND NOT A BEHAVIOURAL ONE. A published raid
%% is checked by replaying it somewhere else, so divergence between two machines
%% is the failure this repository most needs to prevent, and it is exactly the
%% failure a behavioural test on ONE machine cannot see: `math:sin/1' returns the
%% same value here every time, so every assertion about it passes locally and the
%% fight still disagrees with itself on a different libc.
%%
%% Reading the compiled imports catches it at the moment somebody adds the call,
%% which is the only moment it is cheap.
-module(airspace_determinism_tests).

-include_lib("eunit/include/eunit.hrl").

%% Every module on the match path. Named explicitly rather than globbed, because
%% a glob would silently start covering, or stop covering, whatever happened to
%% be compiled beside them.
-define(MATCH_PATH, [fixed, airspace]).

%% ⚠ `math' IS THE ONE THAT MATTERS AND THE OTHERS ARE THE ONES THAT LOOK
%% HARMLESS. A wall clock or a process-global generator does not make two
%% machines disagree; it makes the SAME machine disagree with itself, so a
%% replay of a fight it hosted an hour ago comes out differently and nothing
%% says why.
forbidden() ->
    [{math, any},
     {rand, any},
     {os, timestamp}, {os, system_time}, {os, getenv},
     {erlang, now}, {erlang, system_time}, {erlang, monotonic_time},
     {erlang, timestamp}, {erlang, unique_integer},
     {erlang, make_ref}, {erlang, self}].

the_match_path_calls_nothing_that_could_differ_test() ->
    [?assertEqual({Mod, []}, {Mod, offences(Mod)}) || Mod <- ?MATCH_PATH].

offences(Mod) ->
    {ok, {Mod, [{imports, Imports}]}} = beam_lib:chunks(code:which(Mod), [imports]),
    [{M, F, A} || {M, F, A} <- Imports, banned(M, F)].

banned(M, F) -> lists:any(fun (Rule) -> matches(Rule, M, F) end, forbidden()).

matches({M, any}, M, _F) -> true;
matches({M, F}, M, F) -> true;
matches(_Rule, _M, _F) -> false.

%% ⚠ AND THE CHECK ITSELF IS CHECKED. A guard that cannot be shown to fire is a
%% comment with a function's syntax, and this one reads a call graph, which is
%% easy to get subtly wrong in a way that reports "clean" for every input.
%% `eunit' itself is a module that certainly calls the forbidden list.
the_check_can_actually_find_something_test() ->
    ?assertNotEqual([], offences(fixed_tests)).

%% The sine table is what replaces libm on the match path, so a table that had
%% drifted from its generator would make every fight wrong in the same quiet
%% way. `scripts/generate_sine_table.escript --verify' is the whole check; this
%% asserts the property the table exists for.
the_table_is_what_stands_in_for_libm_test() ->
    ?assertEqual(256, length([fixed:sin(A) || A <- lists:seq(0, 255)])),
    ?assertEqual(fixed:sin(0), fixed:sin(256)),
    ?assertEqual(fixed:sin(64), fixed:cos(0)).
