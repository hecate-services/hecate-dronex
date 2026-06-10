%%% @doc Supervisor for the track-estimate recorder.
-module(on_track_confirmed_record_estimate_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id    => on_track_confirmed_record_estimate,
          start => {on_track_confirmed_record_estimate, start_link, []},
          restart => permanent, shutdown => 5000,
          type  => worker, modules => [on_track_confirmed_record_estimate]}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
