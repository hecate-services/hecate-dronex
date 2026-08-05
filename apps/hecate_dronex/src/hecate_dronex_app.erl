%% @doc OTP application entry.
%%
%% `hecate_om:boot/1' wires the mesh, the realm identity and health, opens the
%% store because `hecate_dronex_service' exports `store_id/0' and `data_dir/0',
%% and then starts this service.
%%
%% ⚠ A COMMENT THAT DESCRIBES A DECISION MUST NAME THE CODE THAT CARRIES IT, so
%% that moving the code breaks the comment visibly. A sibling's version of this
%% file said "STORELESS: no store_id/0 or data_dir/0 callback" for weeks after
%% its service module had grown both and opened a store. This one names
%% `hecate_dronex_service' and says nothing that module does not.
-module(hecate_dronex_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> hecate_om:boot(hecate_dronex_service).

stop(_State) -> ok.
