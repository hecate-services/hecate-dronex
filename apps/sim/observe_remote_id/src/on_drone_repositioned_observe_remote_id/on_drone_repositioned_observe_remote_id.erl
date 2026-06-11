%%% @doc THE SWAP POINT (producer side).
%%%
%%% Reacts to ground-truth `drone_repositioned` events, applies the Remote-ID
%%% sensor model for every Remote-ID sensor in the scenario, and publishes the
%%% resulting `airspace.contact_observed` facts to the mesh. A real Remote-ID
%%% receiver publishes the byte-identical fact on the same topic; fusion cannot
%%% tell this simulated emitter from hardware.
%%%
%%% Implemented as an evoq_projection so it subscribes to one event type. It
%%% keeps no read model of its own (the ETS read model only carries evoq's
%%% checkpoint); its "output" is the side effect of publishing facts.
-module(on_drone_repositioned_observe_remote_id).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).
-export([base_id/1]).   %% exported for regression test (continuous-mode suffix)

interested_in() ->
    [<<"drone_repositioned">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{}),
    {ok, #{}, RM}.

project(#{event_type := <<"drone_repositioned">>, data := Data}, _Meta, State, RM) ->
    observe_and_publish(Data),
    {ok, State, RM};
project(#{event_type := <<"drone_repositioned">>} = Event, _Meta, State, RM) ->
    observe_and_publish(Event),
    {ok, State, RM};
project(_Event, _Meta, State, RM) ->
    {skip, State, RM}.

%%--------------------------------------------------------------------

observe_and_publish(Data) ->
    DroneId = g(drone_id, Data),
    Static  = scenario_drone(DroneId),
    Drone = #{drone_id    => DroneId,
              drone_type  => maps:get(type, Static, <<"unknown">>),
              remote_id   => maps:get(remote_id, Static, absent),
              x           => g(x, Data),
              y           => g(y, Data),
              alt         => g(alt, Data),
              observed_at => g(observed_at, Data)},
    Env   = simulate_weather:current(),
    Topic = airspace_contact_observed:topic(list_to_binary(hecate_dronex_service:site_id())),
    _ = [ publish_observation(Topic, Drone, Sensor, Env)
          || Sensor <- dronex_scenario:sensors(),
             maps:get(modality, Sensor, undefined) =:= remote_id ],
    ok.

publish_observation(Topic, Drone, Sensor, Env) ->
    case remote_id_sensor_model:observe(Drone, Sensor, Env) of
        {ok, Fact} ->
            deliver_local(Fact),
            publish_fact(Topic, Fact);
        miss ->
            ok
    end.

%% Local hand-off to co-located fusion. The macula mesh does NOT deliver a
%% node's own publish back to a subscriber on the same node, so on a single
%% sim node the correlator only sees the contact via this direct message. The
%% mesh publish (publish_fact) still reaches fusion on a SEPARATE node, which
%% is the production sensor topology (sensors and the brain on different nodes).
deliver_local(Fact) ->
    case whereis(on_contact_observed_correlate_track) of
        undefined -> ok;
        Pid       -> Pid ! {dronex_local_contact, Fact}, ok
    end.

%% Inline mesh publish, parksim-style: no-op while the node is dark.
publish_fact(Topic, Fact) ->
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            _ = (catch macula:publish(Pool, Realm, Topic, Fact)),
            ok;
        _ ->
            ok
    end.

%% Continuous mode tags each replay's drone id with a "#<cycle>" suffix; the
%% drone's static attrs (type, remote_id presence) live under the base id in the
%% scenario, so strip the suffix before the lookup.
scenario_drone(DroneId) ->
    Base = base_id(DroneId),
    case [D || D <- dronex_scenario:drones(), maps:get(id, D, undefined) =:= Base] of
        [D | _] -> D;
        []      -> #{}
    end.

base_id(DroneId) when is_binary(DroneId) ->
    case binary:split(DroneId, <<"#">>) of
        [Base | _] -> Base;
        _          -> DroneId
    end;
base_id(DroneId) ->
    DroneId.

g(Key, Map) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
