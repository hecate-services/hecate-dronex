%%% @doc simulate_airspace OTP application entry.
-module(simulate_airspace_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    simulate_airspace_sup:start_link().

stop(_State) ->
    ok.
