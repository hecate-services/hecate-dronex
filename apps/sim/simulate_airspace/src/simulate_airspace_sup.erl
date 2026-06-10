%%% @doc simulate_airspace supervisor.
%%%
%%% The CMD desks (enter/reposition/depart) are pure command paths dispatched
%%% via evoq and own no processes. The only worker is the scenario driver.
-module(simulate_airspace_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id    => run_scenario,
          start => {run_scenario, start_link, []},
          restart => permanent, shutdown => 5000,
          type  => worker, modules => [run_scenario]}
    ],
    {ok, {SupFlags, Children}}.
