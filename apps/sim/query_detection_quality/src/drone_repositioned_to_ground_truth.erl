%%% @doc Projects the simulator's internal ground-truth events into the scorer
%%% store. This is the truth side of the oracle. It reads LOCAL domain events
%%% (never the mesh), so fusion cannot see the answer key.
-module(drone_repositioned_to_ground_truth).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() ->
    [<<"drone_entered_airspace">>, <<"drone_repositioned">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{}),
    {ok, #{}, RM}.

project(#{event_type := <<"drone_entered_airspace">>, data := D}, _M, S, RM) ->
    record(D, entered_at), {ok, S, RM};
project(#{event_type := <<"drone_entered_airspace">>} = Ev, _M, S, RM) ->
    record(Ev, entered_at), {ok, S, RM};
project(#{event_type := <<"drone_repositioned">>, data := D}, _M, S, RM) ->
    record(D, observed_at), {ok, S, RM};
project(#{event_type := <<"drone_repositioned">>} = Ev, _M, S, RM) ->
    record(Ev, observed_at), {ok, S, RM};
project(_Ev, _M, S, RM) ->
    {skip, S, RM}.

record(Data, TimeKey) ->
    query_detection_quality_store:record_ground_truth(
        g(drone_id, Data), g(TimeKey, Data), g(x, Data), g(y, Data), g(alt, Data)).

g(Key, Map) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
