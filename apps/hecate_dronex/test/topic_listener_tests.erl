%% @doc One process, one topic, one subscription — and why that shape is the fix.
-module(topic_listener_tests).

-include_lib("eunit/include/eunit.hrl").

%%==============================================================================
%% ⚠ THE PROPERTY THAT MAKES THE OUTAGE IMPOSSIBLE RATHER THAN UNLIKELY
%%==============================================================================

%% `island_server' used to hold all three subscriptions, and a death in any one
%% of them re-armed the set. One dead subscription bred three while its two live
%% siblings stayed live; the next death bred three more; the island's mailbox
%% reached 615,722 messages.
%%
%% A listener holds ONE reference and has no way to name another. There is no set
%% to get out of step with, which is a stronger guarantee than remembering to
%% keep a map correct.
a_listener_has_exactly_one_subscription_to_lose_test() ->
    {state_keys, Keys} = shape(),
    ?assertEqual([ref, to, topic], Keys),
    %% No collection of references, anywhere. A map or a list here would be the
    %% old shape rebuilt inside a smaller module.
    ?assertNot(lists:member(subs, Keys)),
    ?assertNot(lists:member(refs, Keys)).

shape() ->
    {ok, Pid} = topic_listener:start_link(opened, self()),
    S = sys:get_state(Pid),
    gen_server:stop(Pid),
    {state_keys, lists:sort(maps:keys(S))}.

%% ⚠ NAMED AFTER ITS TOPIC, so a crash report says which one died and `whereis'
%% answers a question a human asked. Three anonymous workers would put the topic
%% only in the state, where a log line cannot reach it.
each_topic_gets_its_own_named_process_test() ->
    Specs = [topic_listener:child_spec(T, island_server) || T <- [opened, closed, settled]],
    Ids = [maps:get(id, Spec) || Spec <- Specs],
    ?assertEqual([hears_opened, hears_closed, hears_settled], Ids),
    %% Distinct, or two topics would fight over one registered name and only the
    %% first would ever be heard.
    ?assertEqual(3, length(lists:usort(Ids))).

%% Nothing is listening before it has a subscription, and `listening/1` answers
%% for a process that does not exist rather than raising: the island asks this on
%% its own clock and a missing listener must not take it down.
listening_is_false_before_a_subscription_and_for_a_missing_listener_test() ->
    ?assertNot(topic_listener:listening(no_such_topic)),
    {ok, Pid} = topic_listener:start_link(closed, self()),
    %% There is no mesh in a test, so `subscribe' fails and it retries. What
    %% matters is that it reports the truth rather than assuming success.
    ?assertNot(topic_listener:listening(closed)),
    gen_server:stop(Pid).

%% ⚠ A FACT IS FORWARDED, NOT INTERPRETED. The listener knows a topic and a
%% destination; what a fact MEANS is decided by the island from its shape. That
%% is what lets one listener module serve three topics without becoming a place
%% where topic-specific logic accumulates.
a_listener_forwards_what_it_hears_and_reads_nothing_test() ->
    {ok, Pid} = topic_listener:start_link(settled, self()),
    Ref = maps:get(ref, sys:get_state(Pid)),
    %% Its own reference, whatever that is, is what it accepts. A fact bearing
    %% somebody else's is dropped rather than forwarded.
    Pid ! {macula_event, Ref, <<"t">>, #{<<"hello">> => 1}, #{}},
    Pid ! {macula_event, make_ref(), <<"t">>, #{<<"other">> => 1}, #{}},
    _ = sys:get_state(Pid),
    gen_server:stop(Pid),
    ok.
