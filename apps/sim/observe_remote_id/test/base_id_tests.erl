%%% @doc Regression: the emitter must recover a drone's BASE id from the
%%% continuous-mode "#<cycle>" suffix, or the scenario lookup for the drone's
%%% static attrs (remote_id presence, type) fails and every observation misses.
%%% (The full-loop test runs non-continuous, so it does not exercise this.)
-module(base_id_tests).
-include_lib("eunit/include/eunit.hrl").

strips_cycle_suffix_test() ->
    ?assertEqual(<<"bogey-1">>, on_drone_repositioned_observe_remote_id:base_id(<<"bogey-1#168">>)).

keeps_base_with_dash_test() ->
    %% Base id itself contains "-", so a "-" suffix would be ambiguous; "#" is not.
    ?assertEqual(<<"bogey-1">>, on_drone_repositioned_observe_remote_id:base_id(<<"bogey-1">>)).

keeps_plain_id_test() ->
    ?assertEqual(<<"intruder">>, on_drone_repositioned_observe_remote_id:base_id(<<"intruder">>)).
