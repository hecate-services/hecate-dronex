%%% @doc THE SWAP POINT (consumer side).
%%%
%%% Subscribes to `airspace.contact_observed` facts on the mesh, correlates
%%% them into tracks, dispatches confirm_track, and publishes the
%%% `airspace.track_confirmed` fact. It does not know or care whether the
%%% contacts came from a simulated emitter or a real sensor.
%%%
%%% Correlation here is the SKELETON minimum: one confirmed track per drone id,
%%% single-sensor passthrough, live position refresh on later contacts. Real
%%% multi-sensor triangulation, track association, and track-lost handling are
%%% the next slices (see DESIGN_DRONEX_SIMULATION.md).
%%%
%%% Mesh subscribe is retried until a macula client + realm are present; while
%%% the node is dark it simply waits, and publishes are no-ops.
-module(on_contact_observed_correlate_track).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RESUBSCRIBE_MS, 2000).
%% A walking drone emits a contact every sim-step (~125ms at the demo time
%% scale); the realm refreshes every 2s and ages tracks stale after 12s, so one
%% track_confirmed per second per track is ample on the wire and keeps the relays
%% from being flooded. Track birth (the first contact) always publishes.
-define(MIN_PUBLISH_MS, 800).

-record(state, {
    contact_topic :: binary(),
    track_topic   :: binary(),
    subscribed = false :: boolean(),
    tracks = #{} :: #{binary() => binary()},   %% drone_id -> track_id
    last_pub = #{} :: #{binary() => integer()}  %% track_id -> last publish (mono ms)
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Site = list_to_binary(hecate_dronex_service:site_id()),
    self() ! try_subscribe,
    {ok, #state{contact_topic = airspace_contact_observed:topic(Site),
                track_topic   = airspace_track_confirmed:topic(Site)}}.

handle_call(_Msg, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)         -> {noreply, State}.

handle_info(try_subscribe, #state{subscribed = false, contact_topic = Topic} = State) ->
    case subscribe(Topic) of
        ok ->
            {noreply, State#state{subscribed = true}};
        retry ->
            erlang:send_after(?RESUBSCRIBE_MS, self(), try_subscribe),
            {noreply, State}
    end;
handle_info(try_subscribe, State) ->
    {noreply, State};
%% macula delivers a 5- or 4-element event depending on SDK version.
handle_info({macula_event, _Ref, _Topic, Fact, _Meta}, State) ->
    {noreply, correlate(Fact, State)};
handle_info({macula_event, _Ref, _Topic, Fact}, State) ->
    {noreply, correlate(Fact, State)};
%% Direct hand-off from a co-located emitter (the mesh doesn't loop same-node
%% publishes; see observe_remote_id deliver_local/1).
handle_info({dronex_local_contact, Fact}, State) when is_map(Fact) ->
    {noreply, correlate(Fact, State)};
handle_info(_Other, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%%--------------------------------------------------------------------

subscribe(Topic) ->
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            case catch macula:subscribe(Pool, Realm, Topic, self()) of
                {ok, _Ref} -> ok;
                _          -> retry
            end;
        _ ->
            retry
    end.

correlate(Fact, #state{tracks = Tracks} = State) ->
    Drone   = airspace_contact_observed:drone(Fact),
    DroneId = drone_id(Drone),
    correlate(DroneId, Drone, Fact, maps:get(DroneId, Tracks, undefined), State).

correlate(undefined, _Drone, _Fact, _Existing, State) ->
    State;
correlate(DroneId, Drone, Fact, undefined, #state{tracks = Tracks} = State) ->
    TrackId = <<"track-", DroneId/binary>>,
    _ = maybe_confirm_track:dispatch(#{
        track_id      => TrackId,
        drone         => Drone,
        x             => pos(x, Fact), y => pos(y, Fact), alt => pos(alt, Fact),
        confidence    => airspace_contact_observed:confidence(Fact),
        sensor_ids    => [airspace_contact_observed:sensor_id(Fact)],
        first_seen_at => airspace_contact_observed:observed_at(Fact)}),
    %% Track birth always publishes; subsequent refreshes are throttled.
    State1 = publish_track(State, TrackId, Fact, force),
    State1#state{tracks = Tracks#{DroneId => TrackId}};
correlate(_DroneId, _Drone, Fact, TrackId, State) when is_binary(TrackId) ->
    %% Existing track: refresh the live fact (no new domain event), throttled.
    publish_track(State, TrackId, Fact, throttle).

%% Throttle per-track refresh publishes; always publish on `force` (birth).
publish_track(#state{last_pub = LastPub} = State, TrackId, Fact, Mode) ->
    Now  = erlang:monotonic_time(millisecond),
    Last = maps:get(TrackId, LastPub, 0),
    case Mode =:= force orelse (Now - Last) >= ?MIN_PUBLISH_MS of
        true ->
            do_publish_track(State, TrackId, Fact),
            State#state{last_pub = LastPub#{TrackId => Now}};
        false ->
            State
    end.

do_publish_track(#state{track_topic = Topic}, TrackId, Fact) ->
    TrackFact = airspace_track_confirmed:new(#{
        track_id      => TrackId,
        drone         => airspace_contact_observed:drone(Fact),
        position      => airspace_contact_observed:position(Fact),
        confidence    => airspace_contact_observed:confidence(Fact),
        sensor_ids    => [airspace_contact_observed:sensor_id(Fact)],
        first_seen_at => airspace_contact_observed:observed_at(Fact)}),
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            _ = (catch macula:publish(Pool, Realm, Topic, TrackFact)),
            ok;
        _ ->
            ok
    end.

%% Extract a coordinate from the contact's position map (atom or binary keys).
pos(Key, Fact) ->
    case airspace_contact_observed:position(Fact) of
        P when is_map(P) ->
            case maps:find(Key, P) of
                {ok, V} -> V;
                error   -> maps:get(atom_to_binary(Key, utf8), P, undefined)
            end;
        _ -> undefined
    end.

drone_id(D) when is_map(D) ->
    case maps:find(id, D) of
        {ok, V} -> V;
        error   -> maps:get(<<"id">>, D, undefined)
    end;
drone_id(_) -> undefined.
