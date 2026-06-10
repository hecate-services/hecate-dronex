%%% @doc CMD-level domain spec for the ground-truth drone-track aggregate.
%%%
%%% Layer A (pure, no store) drives the full enter -> reposition -> depart
%%% lifecycle and every guard rejection, asserting after each command: the
%%% exact events emitted (and no others), the right rejection, and the
%%% resulting state. Layer B replays the happy path through the real dispatcher
%%% against mem-evoq, proving the events persist under a reckon-db-valid
%%% stream id (`drn-<md5>`).
-module(drone_track_aggregate_spec_tests).
-include_lib("eunit/include/eunit.hrl").

-define(AGG, drone_track_aggregate).

sid() -> drone_track_aggregate:stream_id(<<"bogey-1">>).
did() -> <<"bogey-1">>.

enter_payload() ->
    #{drone_id => did(), drone_type => <<"DJI Mavic 3">>, remote_id => present,
      x => 0, y => 0, alt => 0}.
reposition_payload(X, Y, A) ->
    #{drone_id => did(), x => X, y => Y, alt => A, observed_at => 1000}.
depart_payload() ->
    #{drone_id => did()}.

in_airspace(S) -> drone_track_state:is_in_airspace(S).
departed(S)    -> drone_track_state:is_departed(S).

%%====================================================================
%% Layer A — full lifecycle
%%====================================================================

lifecycle_test() ->
    E = fun(T) -> evoq_aggregate_spec:expect([T]) end,
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {enter_airspace, enter_payload(), E(<<"drone_entered_airspace">>),
              fun in_airspace/1},
        {reposition_drone, reposition_payload(80, 30, 60), E(<<"drone_repositioned">>),
              fun(S) -> in_airspace(S) andalso not departed(S) end},
        {reposition_drone, reposition_payload(140, 60, 80), E(<<"drone_repositioned">>),
              fun in_airspace/1},
        {depart_airspace, depart_payload(), E(<<"drone_departed">>),
              fun departed/1}
    ]).

%%====================================================================
%% Layer A — guards
%%====================================================================

reposition_before_entry_rejected_test() ->
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {reposition_drone, reposition_payload(10, 10, 5),
              evoq_aggregate_spec:expect_error(drone_not_in_airspace),
              evoq_aggregate_spec:unchanged()}
    ]).

depart_before_entry_rejected_test() ->
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {depart_airspace, depart_payload(),
              evoq_aggregate_spec:expect_error(drone_not_in_airspace),
              evoq_aggregate_spec:unchanged()}
    ]).

double_entry_rejected_test() ->
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {enter_airspace, enter_payload(),
              evoq_aggregate_spec:expect([<<"drone_entered_airspace">>]),
              fun in_airspace/1},
        {enter_airspace, enter_payload(),
              evoq_aggregate_spec:expect_error(drone_already_in_airspace),
              evoq_aggregate_spec:unchanged()}
    ]).

reposition_after_depart_rejected_test() ->
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {enter_airspace, enter_payload(),
              evoq_aggregate_spec:expect([<<"drone_entered_airspace">>]), fun in_airspace/1},
        {depart_airspace, depart_payload(),
              evoq_aggregate_spec:expect([<<"drone_departed">>]), fun departed/1},
        {reposition_drone, reposition_payload(1, 1, 1),
              evoq_aggregate_spec:expect_error(drone_already_departed),
              evoq_aggregate_spec:unchanged()}
    ]).

%%====================================================================
%% Layer B — persistence + stream-id boundary
%%====================================================================

dispatch_persists_lifecycle_test() ->
    evoq_cmd_case:with_mem_store(fun(StoreId) ->
        Sid = sid(),
        Scenario = [
            {enter_airspace, enter_payload()},
            {reposition_drone, reposition_payload(80, 30, 60)},
            {depart_airspace, depart_payload()}
        ],
        ok = evoq_cmd_case:dispatch_all(?AGG, Sid, Scenario, StoreId),
        evoq_cmd_case:assert_stream(StoreId, Sid,
            [<<"drone_entered_airspace">>, <<"drone_repositioned">>, <<"drone_departed">>])
    end).

valid_stream_id_test() ->
    ok = evoq_cmd_case:assert_valid_stream_id(sid()).
