%%% @doc fuse_airspace supervisor.
%%%
%%% The confirm_track desk is a pure command path (no process). The correlator
%%% process manager is a sibling slice, supervised here.
-module(fuse_airspace_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id    => on_contact_observed_correlate_track_sup,
          start => {on_contact_observed_correlate_track_sup, start_link, []},
          restart => permanent, shutdown => 5000,
          type  => supervisor, modules => [on_contact_observed_correlate_track_sup]}
    ],
    {ok, {SupFlags, Children}}.
