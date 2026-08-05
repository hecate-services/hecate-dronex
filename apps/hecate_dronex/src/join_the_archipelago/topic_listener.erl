%% @doc One process, one topic, one subscription. Forever.
%%
%% THIS EXISTS BECAUSE ONE PROCESS HOLDING THREE SUBSCRIPTIONS BRED SIX HUNDRED
%% THOUSAND MESSAGES.
%%
%% ==========================================================================
%% ⚠ THE BUG WAS THE SHAPE, NOT THE LINE
%% ==========================================================================
%%
%% `island_server' subscribed to all three inter-island topics itself and tracked
%% whether it had, first with one boolean and then — after the boolean caused an
%% outage — with a map of topic to reference. Both are the same mistake in
%% different clothes: **one process managing a set of unrelated subscriptions**,
%% which is a horizontal layer wearing a gen_server's syntax.
%%
%% With the boolean, `{macula_event_gone, Ref, _}' for ANY ONE subscription
%% cleared it and re-subscribed all three, so one death bred three while its two
%% live siblings stayed live. The next death bred three more. The island's
%% mailbox reached 615,722 messages, it wedged inside `macula_client:subscribe'
%% making it worse, and the visible symptoms — raids stuck in flight, failed
%% publishes, a snapshot call timing out — all pointed somewhere else.
%%
%% The map version fixed that instance. It did not fix the shape: a single
%% process still owned every subscription, so every future subscription bug had
%% one blast radius covering all of them.
%%
%% ==========================================================================
%% ⚠⚠ WHAT ONE-PER-TOPIC MAKES IMPOSSIBLE RATHER THAN MERELY UNLIKELY
%% ==========================================================================
%%
%% A process here holds exactly one subscription and has no way to name another.
%% There is no set to get out of step with, no shared flag, and nothing to
%% re-arm on somebody else's behalf. A dead subscription re-arms itself; a dead
%% LISTENER is restarted by the supervisor and subscribes once on the way up.
%%
%% The island is no longer the subscription manager. It is told what arrived.
-module(topic_listener).

-behaviour(gen_server).

-export([start_link/2, child_spec/2, listening/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

%% Long enough that a mesh which is not up yet costs a few seconds rather than a
%% deployment, short enough that nobody is waiting on it.
-define(RETRY_MS, 15000).

%% @doc Start a listener for one topic, forwarding what arrives to `To'.
-spec start_link(atom(), atom()) -> {ok, pid()} | {error, term()}.
start_link(Topic, To) ->
    gen_server:start_link({local, name(Topic)}, ?MODULE, {Topic, To}, []).

%% ⚠ NAMED AFTER ITS TOPIC, so that `whereis' answers a question a human asked
%% and a crash report says which one died. An unnamed pool of identical workers
%% would put the topic only in the state, where a log line cannot reach it.
-spec child_spec(atom(), atom()) -> supervisor:child_spec().
child_spec(Topic, To) ->
    #{id => name(Topic),
      start => {?MODULE, start_link, [Topic, To]},
      restart => permanent,
      shutdown => 5000,
      type => worker}.

%% @doc Whether this topic currently has a live subscription.
-spec listening(atom()) -> boolean().
listening(Topic) -> asked(erlang:whereis(name(Topic))).

asked(undefined) -> false;
asked(Pid) ->
    try gen_server:call(Pid, listening, 1000)
    catch _:_ -> false
    end.

name(Topic) -> list_to_atom("hears_" ++ atom_to_list(Topic)).

%%==============================================================================
%% gen_server
%%==============================================================================

init({Topic, To}) ->
    self() ! subscribe,
    {ok, #{topic => Topic, to => To, ref => undefined}}.

handle_call(listening, _From, #{ref := Ref} = S) -> {reply, Ref =/= undefined, S};
handle_call(_Other, _From, S) -> {reply, {error, unknown_call}, S}.

handle_cast(_Msg, S) -> {noreply, S}.

%% ⚠ SUBSCRIBES ONLY WHEN IT HOLDS NONE. The guard is on this process's own
%% single reference, which is the whole reason a listener cannot multiply itself:
%% there is no set to be inconsistent with.
handle_info(subscribe, #{ref := undefined, topic := Topic} = S) ->
    {noreply, armed(dronex_mesh:subscribe_between_islands(dronex_facts:topic(Topic), self()), S)};
handle_info(subscribe, S) ->
    {noreply, S};

%% ⚠ FIVE ELEMENTS. A four-element clause matches nothing, every fact falls to
%% the catch-all, and the subscription looks perfectly healthy while delivering
%% nothing. A sibling shipped exactly that and it cost an hour.
handle_info({macula_event, Ref, _Topic, Fact, _Meta}, #{ref := Ref, to := To} = S) ->
    gen_server:cast(To, {heard, Fact}),
    {noreply, S};

%% Somebody else's reference. Cannot happen while this process holds one
%% subscription, and dropped rather than forwarded if it ever does.
handle_info({macula_event, _Other, _Topic, _Fact, _Meta}, S) ->
    {noreply, S};

handle_info({macula_event_gone, Ref, Why}, #{ref := Ref, topic := Topic} = S) ->
    logger:warning("[hears_~s] subscription gone (~p), re-arming", [Topic, Why]),
    self() ! subscribe,
    {noreply, S#{ref := undefined}};

handle_info(_Msg, S) ->
    {noreply, S}.

armed({ok, Ref}, #{topic := Topic} = S) ->
    logger:info("[hears_~s] listening", [Topic]),
    S#{ref := Ref};
%% A mesh that is not up yet is not a failure of the island: it breeds, measures
%% itself and publishes regardless. This simply tries again.
armed({error, _Why}, S) ->
    erlang:send_after(?RETRY_MS, self(), subscribe),
    S.
