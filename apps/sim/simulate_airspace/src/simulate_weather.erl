%%% @doc Environment the sensors operate in (wind, visibility, ...). Sensor
%%% models read this to degrade detection: wind hurts acoustic, low visibility
%%% hurts EO/IR, and so on.
%%%
%%% In this skeleton the environment is the static block from the scenario.
%%% This module is the seam where dynamic weather (fronts, gusts, day/night)
%%% plugs in later, without touching any sensor model.
-module(simulate_weather).

-export([current/0]).

-spec current() -> map().
current() ->
    dronex_scenario:environment().
