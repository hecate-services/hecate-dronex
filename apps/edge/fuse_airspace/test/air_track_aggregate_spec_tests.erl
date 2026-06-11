%%% @doc CMD-level domain spec for the airspace-track aggregate (edge brain).
%%%
%%% Layer A proves a track confirms exactly once and a second confirm is
%%% rejected. Layer B proves the confirm persists under a reckon-db-valid
%%% stream id (`trk-<md5>`).
-module(air_track_aggregate_spec_tests).
-include_lib("eunit/include/eunit.hrl").

-define(AGG, air_track_aggregate).

%% Unique track id: the over-mesh tests create "track-bogey-1", and evoq's
%% aggregate registry is global per (module, stream_id).
tid() -> <<"spec-track-1">>.
sid() -> air_track_aggregate:stream_id(tid()).

confirm_payload() ->
    #{track_id   => tid(),
      drone      => #{id => <<"bogey-1">>, type => <<"DJI Mavic 3">>},
      x          => 80, y => 30, alt => 60,
      confidence => 0.95,
      sensor_ids => [<<"ne-03">>],
      first_seen_at => 1000}.

confirmed(S) -> air_track_state:is_confirmed(S).

%%====================================================================
%% Layer A
%%====================================================================

confirm_once_test() ->
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {confirm_track, confirm_payload(),
              evoq_aggregate_spec:expect([<<"track_confirmed">>]),
              fun confirmed/1}
    ]).

second_confirm_rejected_test() ->
    ok = evoq_aggregate_spec:run(?AGG, sid(), [
        {confirm_track, confirm_payload(),
              evoq_aggregate_spec:expect([<<"track_confirmed">>]), fun confirmed/1},
        {confirm_track, confirm_payload(),
              evoq_aggregate_spec:expect_error(track_already_confirmed),
              evoq_aggregate_spec:unchanged()}
    ]).

%%====================================================================
%% Layer B — persistence + stream-id boundary
%%====================================================================

dispatch_persists_test() ->
    evoq_cmd_case:with_mem_store(fun(StoreId) ->
        Sid = sid(),
        ok = evoq_cmd_case:dispatch_all(?AGG, Sid, [{confirm_track, confirm_payload()}], StoreId),
        evoq_cmd_case:assert_stream(StoreId, Sid, [<<"track_confirmed">>])
    end).

valid_stream_id_test() ->
    ok = evoq_cmd_case:assert_valid_stream_id(sid()).
