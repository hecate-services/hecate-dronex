%%% @doc Read facade for the detection-quality scorer.
-module(query_detection_quality).

-export([overview/0]).

%% @doc Current scores for the run: detection latency, track RMSE, missed and
%% false-track counts, id accuracy.
-spec overview() -> {ok, map()}.
overview() ->
    {ok, score_detection:overview()}.
