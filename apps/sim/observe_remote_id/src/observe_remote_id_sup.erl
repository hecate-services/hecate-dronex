%%% @doc observe_remote_id supervisor. Starts the emitter projection that
%%% subscribes to ground-truth events and publishes contact_observed facts.
-module(observe_remote_id_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id    => on_drone_repositioned_observe_remote_id,
          start => {evoq_projection, start_link,
                    [on_drone_repositioned_observe_remote_id, #{},
                     #{store_id => hecate_dronex_service:store_id()}]},
          restart => permanent, shutdown => 5000,
          type  => worker, modules => [evoq_projection]}
    ],
    {ok, {SupFlags, Children}}.
