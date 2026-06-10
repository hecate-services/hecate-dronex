%%% @doc query_detection_quality supervisor.
%%%
%%% Owns the scorer store, the ground-truth projection (reads local events),
%%% and the estimate recorder (reads track_confirmed facts off the mesh).
-module(query_detection_quality_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id    => query_detection_quality_store,
          start => {query_detection_quality_store, start_link, []},
          restart => permanent, shutdown => 5000,
          type  => worker, modules => [query_detection_quality_store]},

        #{id    => drone_repositioned_to_ground_truth,
          start => {evoq_projection, start_link,
                    [drone_repositioned_to_ground_truth, #{},
                     #{store_id => hecate_dronex_service:store_id()}]},
          restart => permanent, shutdown => 5000,
          type  => worker, modules => [evoq_projection]},

        #{id    => on_track_confirmed_record_estimate_sup,
          start => {on_track_confirmed_record_estimate_sup, start_link, []},
          restart => permanent, shutdown => 5000,
          type  => supervisor, modules => [on_track_confirmed_record_estimate_sup]}
    ],
    {ok, {SupFlags, Children}}.
