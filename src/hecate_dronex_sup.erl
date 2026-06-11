%%% @doc Root shell supervisor.
%%%
%%% Owns only the HTTP admin/query surface. Each domain app (fuse_airspace,
%%% simulate_airspace, ...) supervises its own processes from its own app
%%% supervisor. Integration facts cross the macula mesh directly (no node-wide
%%% bus); publishers no-op while the node is dark, exactly like parksim.
-module(hecate_dronex_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [cowboy_child()],
    {ok, {SupFlags, Children}}.

cowboy_child() ->
    Port = hecate_dronex_service:http_port(),
    Dispatch = cowboy_router:compile([{'_', [{"/health", hecate_om_health_handler, []} | role_routes()]}]),
    #{id    => cowboy_listener,
      start => {cowboy, start_clear, [
          hecate_dronex_http_listener,
          [{port, Port}],
          #{env => #{dispatch => Dispatch}}
      ]},
      restart => permanent, shutdown => 5000,
      type  => worker, modules => [cowboy]}.

%% The scoring API only exists in the dronex_sim release (it needs ground
%% truth). The edge release never references the module.
role_routes() ->
    case hecate_dronex_service:role() of
        sim -> [{"/api/detection-quality", query_detection_quality_api, [overview]}];
        _   -> []
    end.
