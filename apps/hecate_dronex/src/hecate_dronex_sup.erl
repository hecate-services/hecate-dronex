%% @doc Supervises this service's own processes.
%%
%% ONE CHILD AT THIS COMMIT: the island. It holds this node's roster and keeps
%% its clock moving.
%%
%% ⚠ THE ROSTER IS NOT YET PERSISTED, AND SAYING SO IS THE POINT. The store is
%% open, because `hecate_dronex_service' exports `store_id/0', and nothing writes
%% to it yet. So a restart loses whatever the island held. That is honest at
%% order-of-work item 1 and it stops being acceptable at item 5, where the roster
%% arrives: a trained swarm is expensive to produce and an island that loses it
%% on every container recreate is a recording of its own first ten minutes.
%%
%% one_for_one because of the shape that is coming. The trainer, the raid
%% listener and the static defence are independent of the island's clock: a
%% trainer that crashes must not take the roster with it, and an island whose
%% raid listener cannot reach the mesh carries on breeding regardless.
-module(hecate_dronex_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10},
          [#{id => island_server,
             start => {island_server, start_link, []},
             restart => permanent,
             shutdown => 5000,
             type => worker}]}}.
