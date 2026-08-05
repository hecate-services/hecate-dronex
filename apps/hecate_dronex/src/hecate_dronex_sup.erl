%% @doc Supervises this service's own processes.
%%
%% ONE CHILD AT THIS COMMIT: the island. It holds this node's roster and keeps
%% its clock moving.
%%
%% TWO CHILDREN SINCE ITEM 5: the island, and the one process allowed to block on
%% the store.
%%
%% ⚠ THE WRITER IS STARTED FIRST AND THAT ORDER IS LOAD BEARING. `one_for_one'
%% starts children in the order listed, and the island casts snapshots at it from
%% two minutes after boot. A cast to a name that does not exist is a silent
%% no-op, so the island would persist nothing and report nothing wrong.
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
          [#{id => roster_log_writer,
             start => {roster_log_writer, start_link, []},
             restart => permanent,
             shutdown => 5000,
             type => worker},
           #{id => island_server,
             start => {island_server, start_link, []},
             restart => permanent,
             shutdown => 5000,
             type => worker}]}}.
