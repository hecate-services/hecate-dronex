%%% @doc query_detection_quality OTP application entry.
-module(query_detection_quality_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    query_detection_quality_sup:start_link().

stop(_State) ->
    ok.
