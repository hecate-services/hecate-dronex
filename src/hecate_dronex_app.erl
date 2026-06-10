%%% @doc hecate-dronex OTP application entry.
%%%
%%% Boots the hecate_om service substrate (mesh identity, store wiring,
%%% health). hecate_om calls back into hecate_dronex_service for the store
%%% and capability spec.
-module(hecate_dronex_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    hecate_om:boot(hecate_dronex_service).

stop(_State) ->
    ok.
