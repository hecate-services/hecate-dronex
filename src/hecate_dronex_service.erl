%%% @doc hecate-dronex — implements the hecate_om_service behaviour.
%%%
%%% One reckon-db store per site, `dronex_<site>_store`. Site identity comes
%%% from SITE_ID; role (sim | edge) from DRONEX_ROLE. The dronex_sim release
%%% writes ground-truth + track events into this store; the dronex_edge
%%% release writes only track events.
-module(hecate_dronex_service).
-behaviour(hecate_om_service).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).
-export([store_id/0, data_dir/0]).
-export([site_id/0, role/0, time_scale/0, seed/0, scenario/0, continuous/0, http_port/0]).

info() ->
    #{name        => <<"hecate-dronex">>,
      version     => <<"0.1.0">>,
      description => <<"Federated counter-UAS airspace awareness (edge brain + simulator)">>}.

start(_Opts) ->
    {ok, SupPid} = hecate_dronex_sup:start_link(),
    ok = ensure_store(),
    ok = ensure_subscription(),
    {ok, SupPid}.

stop(_State) -> ok.

health() -> ok.

capabilities() ->
    %% The walking skeleton advertises nothing on the mesh. Facts cross via
    %% dronex_fact_bus (macula when meshed, local pg when dark).
    [].

identity_spec() ->
    #{scope => <<"hecate-dronex">>, actions => [], resources => [], ttl_days => 30}.

%%--------------------------------------------------------------------
%% Store wiring (consumed by hecate_om:boot/1)

ensure_store() ->
    Config = #store_config{store_id = store_id(), data_dir = data_dir(), mode = single},
    case reckon_db_sup:start_store(Config) of
        {ok, _Pid}                    -> ok;
        {error, {already_started, _}} -> ok;
        {error, Reason}               -> error({store_start_failed, Reason})
    end.

ensure_subscription() ->
    case evoq_store_subscription:start_link(store_id()) of
        {ok, _Pid}                    -> ok;
        {error, {already_started, _}} -> ok;
        {error, Reason}               -> error({store_subscription_failed, Reason})
    end.

-spec store_id() -> atom().
store_id() ->
    list_to_atom("dronex_" ++ site_slug() ++ "_store").

-spec data_dir() -> string().
data_dir() ->
    case os:getenv("HECATE_DATA_DIR") of
        false -> "/var/lib/hecate-dronex";
        Dir   -> Dir
    end.

%%--------------------------------------------------------------------
%% Site / role identity

-spec site_id() -> string().
site_id() ->
    case os:getenv("SITE_ID") of
        false -> application:get_env(hecate_dronex, site_id, "demo");
        ""    -> application:get_env(hecate_dronex, site_id, "demo");
        Id    -> Id
    end.

-spec role() -> sim | edge.
role() ->
    case os:getenv("DRONEX_ROLE") of
        "sim"  -> sim;
        "edge" -> edge;
        _      -> application:get_env(hecate_dronex, role, edge)
    end.

-spec time_scale() -> float().
time_scale() ->
    case os:getenv("DRONEX_TIME_SCALE") of
        false -> float(application:get_env(hecate_dronex, time_scale, 1.0));
        S     -> parse_pos_float(S, 1.0)
    end.

-spec seed() -> integer().
seed() ->
    case os:getenv("DRONEX_SEED") of
        false -> application:get_env(hecate_dronex, seed, 0);
        S     -> list_to_integer(S)
    end.

-spec scenario() -> string().
scenario() ->
    case os:getenv("DRONEX_SCENARIO") of
        false -> application:get_env(hecate_dronex, scenario, "perimeter_probe");
        S     -> S
    end.

%% @doc HTTP admin/query port. Overridable via DRONEX_HTTP_PORT, because the
%% beam nodes already run other BEAM services binding 8473-8475 (parksim +
%% reckon-gateway) and the dronex container shares host networking.
-spec http_port() -> inet:port_number().
http_port() ->
    case os:getenv("DRONEX_HTTP_PORT") of
        false -> application:get_env(hecate_dronex, http_port, 8484);
        ""    -> application:get_env(hecate_dronex, http_port, 8484);
        P     -> list_to_integer(P)
    end.

%% @doc Continuous mode: the scenario driver replays each drone forever (with a
%% fresh id per cycle) so a live demo keeps showing activity. Off by default so
%% tests see a single deterministic pass. DRONEX_CONTINUOUS=true|1 enables it.
-spec continuous() -> boolean().
continuous() ->
    case os:getenv("DRONEX_CONTINUOUS") of
        "true" -> true;
        "1"    -> true;
        _      -> application:get_env(hecate_dronex, continuous, false)
    end.

%%--------------------------------------------------------------------
%% Internal

%% Site id as a store-safe slug (lowercase, alnum + underscore).
site_slug() ->
    [ case C of
          C when C >= $a, C =< $z -> C;
          C when C >= $0, C =< $9 -> C;
          C when C >= $A, C =< $Z -> C + 32;
          _                       -> $_
      end || C <- site_id() ].

%% Accept both "30" and "30.0"; list_to_float/1 throws on integer-form strings.
parse_pos_float(S, Default) ->
    Parsed = case string:to_float(S) of
                 {F, _} when is_float(F) -> F;
                 _ -> case string:to_integer(S) of
                          {I, _} when is_integer(I) -> float(I);
                          _                         -> Default
                      end
             end,
    case Parsed of
        N when is_number(N), N > 0 -> float(N);
        _                          -> Default
    end.
