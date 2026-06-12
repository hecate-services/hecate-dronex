%%% @doc Validates the perimeter_patrol scenario: every drone is a patrol drone,
%%% and every patrol path is CLOSED (first waypoint position == last waypoint
%%% position). A non-closed loop would teleport the drone each time the patrol
%%% repeats, so this guards the seamless-loop assumption run_scenario relies on.
-module(perimeter_patrol_scenario_tests).
-include_lib("eunit/include/eunit.hrl").

scenario() ->
    File = filename:join([code:lib_dir(simulate_airspace), "priv", "scenarios",
                          "perimeter_patrol.eterm"]),
    {ok, [{scenario, Map}]} = file:consult(File),
    Map.

has_drones_test() ->
    Drones = maps:get(drones, scenario()),
    ?assert(length(Drones) >= 3).

all_patrol_test() ->
    Drones = maps:get(drones, scenario()),
    ?assert(lists:all(fun(D) -> maps:get(patrol, D, false) =:= true end, Drones)).

loops_are_closed_test() ->
    Drones = maps:get(drones, scenario()),
    lists:foreach(fun(D) ->
        Path  = maps:get(path, D),
        First = hd(Path),
        Last  = lists:last(Path),
        Pos   = fun(W) -> {maps:get(x, W), maps:get(y, W), maps:get(alt, W)} end,
        ?assertEqual({maps:get(id, D), Pos(First)}, {maps:get(id, D), Pos(Last)})
    end, Drones).

all_have_remote_id_present_test() ->
    %% Patrol drones must broadcast Remote-ID, or the Remote-ID sensor model
    %% never produces a contact and they stay invisible on the radar.
    Drones = maps:get(drones, scenario()),
    ?assert(lists:all(fun(D) -> maps:get(remote_id, D, absent) =:= present end, Drones)).
