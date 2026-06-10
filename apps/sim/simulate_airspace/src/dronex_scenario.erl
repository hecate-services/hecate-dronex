%%% @doc Loads the active scenario (drones, sensors, environment) from
%%% priv/scenarios/<name>.eterm. The scenario name comes from
%%% hecate_dronex_service:scenario/0 (DRONEX_SCENARIO env / sys.config).
%%%
%%% Cached in persistent_term after first read: run_scenario reads drones once,
%%% but the sensor emitter reads sensors/environment on every observation.
-module(dronex_scenario).

-export([load/0, drones/0, sensors/0, environment/0]).

-spec load() -> map().
load() ->
    case persistent_term:get({?MODULE, scenario}, undefined) of
        undefined ->
            M = read(),
            persistent_term:put({?MODULE, scenario}, M),
            M;
        M -> M
    end.

-spec drones() -> [map()].
drones() -> maps:get(drones, load(), []).

-spec sensors() -> [map()].
sensors() -> maps:get(sensors, load(), []).

-spec environment() -> map().
environment() -> maps:get(environment, load(), #{}).

%%--------------------------------------------------------------------

read() ->
    Name = hecate_dronex_service:scenario(),
    File = filename:join([code:priv_dir(simulate_airspace), "scenarios", Name ++ ".eterm"]),
    case file:consult(File) of
        {ok, [{scenario, Map}]} when is_map(Map) -> Map;
        {ok, [Map]} when is_map(Map)             -> Map;
        {error, Reason}                          -> error({scenario_load_failed, File, Reason})
    end.
