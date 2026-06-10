%%% @doc Scalable simulation clock. Scale 1.0 = real time; scale 10 = ten
%%% simulated seconds per real second, so an N-minute incursion replays fast
%%% in CI or in real time for a demo. The scale comes from
%%% hecate_dronex_service:time_scale/0 (DRONEX_TIME_SCALE).
-module(simulate_clock).

-export([now_unix/0, now_iso8601/0, sleep_simulated/1, scale/0]).

-spec now_unix() -> integer().
now_unix() ->
    erlang:system_time(second).

-spec now_iso8601() -> binary().
now_iso8601() ->
    {{Y, Mo, D}, {H, Mi, S}} =
        calendar:system_time_to_universal_time(erlang:system_time(second), second),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ", [Y, Mo, D, H, Mi, S])).

%% @doc Sleep for `SimulatedMs` of simulated time; real sleep is that divided
%% by the scale, clamped to >= 1 ms.
-spec sleep_simulated(non_neg_integer()) -> ok.
sleep_simulated(0)  -> ok;
sleep_simulated(Ms) when Ms > 0 ->
    timer:sleep(max(1, round(Ms / scale()))).

-spec scale() -> float().
scale() ->
    case hecate_dronex_service:time_scale() of
        N when is_number(N), N > 0 -> float(N);
        _                          -> 1.0
    end.
