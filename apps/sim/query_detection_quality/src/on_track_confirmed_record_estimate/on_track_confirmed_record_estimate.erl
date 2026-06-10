%%% @doc Records fusion's `airspace.track_confirmed` facts as estimates for the
%%% scorer. The estimate side of the oracle: it reads the MESH fact (the same
%%% one peer sites and alerting see), so the score reflects what fusion really
%%% published, not an internal shortcut.
-module(on_track_confirmed_record_estimate).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RESUBSCRIBE_MS, 2000).

-record(state, {topic :: binary(), subscribed = false :: boolean()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Site = list_to_binary(hecate_dronex_service:site_id()),
    self() ! try_subscribe,
    {ok, #state{topic = airspace_track_confirmed:topic(Site)}}.

handle_call(_M, _F, S) -> {reply, ok, S}.
handle_cast(_M, S)      -> {noreply, S}.

handle_info(try_subscribe, #state{subscribed = false, topic = Topic} = S) ->
    case subscribe(Topic) of
        ok    -> {noreply, S#state{subscribed = true}};
        retry -> erlang:send_after(?RESUBSCRIBE_MS, self(), try_subscribe), {noreply, S}
    end;
handle_info(try_subscribe, S) ->
    {noreply, S};
handle_info({macula_event, _Ref, _Topic, Fact, _Meta}, S) ->
    record(Fact), {noreply, S};
handle_info({macula_event, _Ref, _Topic, Fact}, S) ->
    record(Fact), {noreply, S};
handle_info(_Other, S) ->
    {noreply, S}.

terminate(_Reason, _State) -> ok.

%%--------------------------------------------------------------------

subscribe(Topic) ->
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            case catch macula:subscribe(Pool, Realm, Topic, self()) of
                {ok, _Ref} -> ok;
                _          -> retry
            end;
        _ -> retry
    end.

record(Fact) ->
    TrackId = airspace_track_confirmed:track_id(Fact),
    Drone   = airspace_track_confirmed:drone(Fact),
    DroneId = drone_id(Drone),
    Pos     = airspace_track_confirmed:position(Fact),
    T       = airspace_track_confirmed:confirmed_at(Fact),
    Conf    = airspace_track_confirmed:confidence(Fact),
    query_detection_quality_store:record_estimate(
        TrackId, DroneId, T, pos(x, Pos), pos(y, Pos), Conf).

pos(Key, P) when is_map(P) ->
    case maps:find(Key, P) of
        {ok, V} -> V;
        error   -> maps:get(atom_to_binary(Key, utf8), P, undefined)
    end;
pos(_Key, _) -> undefined.

drone_id(D) when is_map(D) ->
    case maps:find(id, D) of
        {ok, V} -> V;
        error   -> maps:get(<<"id">>, D, undefined)
    end;
drone_id(_) -> undefined.
