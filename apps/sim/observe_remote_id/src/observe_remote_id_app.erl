%%% @doc observe_remote_id OTP application entry.
-module(observe_remote_id_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    observe_remote_id_sup:start_link().

stop(_State) ->
    ok.
