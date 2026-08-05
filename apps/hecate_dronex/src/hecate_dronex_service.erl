%% @doc The hecate_om service contract: what this service is and may do.
%%
%% SIX CALLBACKS, ALL REQUIRED. hecate_om calls every one of them during boot,
%% and a missing export fails at startup with `undef' against the live mesh
%% rather than at compile time. Two sibling services learned that the expensive
%% way, so `hecate_dronex_service_tests' asserts the six are exported.
%%
%% IT ANNOUNCES NOTHING, ON PURPOSE. An island with no roster has no capability
%% to offer and asks the realm for authority over no topic it does not publish
%% on. Advertising `dronex.accept_raid' before anything can run one would put a
%% lie on the mesh, and another island could find it and call it. Both lists grow
%% in the same commit as the thing they name.
-module(hecate_dronex_service).

-behaviour(hecate_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).
%% ==========================================================================
%% AND TWO OPTIONAL ONES, WHICH TURN THE STORE ON
%% ==========================================================================
%%
%% Exporting `store_id/0' and `data_dir/0' together makes `hecate_om:boot/1'
%% open a reckon-db store before this module's `start/1' fires.
%%
%% ⚠ THE reckon-db APPLICATIONS RUN EITHER WAY. `reckon_db', `reckon_evoq',
%% `reckon_gater', `evoq', `khepri' and `ra' start with `hecate_om' whether these
%% callbacks exist or not. What the two add is a STORE: a data directory, an open
%% handle, and something written.
%%
%% ⚠⚠ AND THE MOMENT THEY EXIST, `config/sys.config.src' MUST CARRY THE `evoq'
%% BLOCK. hecate_om then starts a per-store evoq subscription which reads the
%% global log, and that crashes on `{not_configured, event_store_adapter}'
%% without it. evoq starts as a release-boot application before any service's
%% `start/2' runs, so nothing can inject it later. A sibling put two of three
%% fleet nodes into a boot-crash loop this exact way.
%%
%% ==========================================================================
%% WHY THEY ARE HERE AT ITEM 1, BEFORE ANYTHING WRITES
%% ==========================================================================
%%
%% Because the failure above happens at BOOT, in a container, on a fleet node,
%% and not on a laptop. Adding the callbacks at item 5 with the roster would mean
%% discovering the config coupling at the moment the interesting work lands.
%% Turning the store on now, with nothing in it, costs a directory and proves the
%% boot path.
%%
%% ⚠ SO A RESTART STILL LOSES THE ISLAND TODAY. The store is open and nothing
%% writes to it. `hecate_dronex_sup' says the same thing where a reader of the
%% supervisor would look.
-export([store_id/0, data_dir/0]).

info() ->
    #{name => <<"hecate-dronex">>,
      version => <<"0.1.0">>,
      description => <<"One island: a roster of drone controllers, an airspace, "
                       "and a network that defends it">>}.

start(_Opts) -> hecate_dronex_sup:start_link().

stop(_State) -> ok.

%% Green once the service is up. A dark mesh is deliberately NOT a health
%% failure: an island whose neighbours are unreachable is still an island. Its
%% trainer runs, its roster grows, and the only thing lost is that nobody else
%% hears about it and nobody attacks it. CHARTER.md makes that the design rather
%% than an inconvenience.
health() -> ok.

%% WHAT THIS SERVICE ANNOUNCES IT CAN DO. Nothing yet, and that is not an
%% oversight. A capability is a promise that something answers when another
%% island calls it. Accepting a raid is the first real one and it goes here
%% together with the code that runs one.
capabilities() -> [].

%% THE AUTHORITY THIS SERVICE ASKS THE REALM FOR.
%%
%% ⚠ EXACTLY THE TOPICS THIS ISLAND PUBLISHES ON, AND NO MORE. Read from
%% `dronex_facts:topics/0' rather than written out here, because authority in two
%% places is authority that drifts: a sibling quietly published on two topics its
%% spec did not name. Popped, an attacker gains precisely the ability to post
%% vitals for one island, which is the whole point of listing it.
identity_spec() ->
    #{scope => <<"dronex">>,
      actions => [<<"publish">>],
      resources => dronex_facts:topics(),
      ttl_days => 30}.

%% ==========================================================================
%% The store
%% ==========================================================================

%% @doc The reckon-db store this island owns.
%%
%% One per island rather than one per run, because the thing worth keeping spans
%% runs: a roster is a LINEAGE, and a node that has bred for a month should be
%% askable what it found, not what it holds this minute.
-spec store_id() -> atom().
store_id() -> dronex_store.

%% @doc Where it lives on disk.
%%
%% ⚠ DEFAULTS TO A PATH INSIDE THE CONTAINER AND MUST NOT STAY THERE ON A NODE.
%% The beam fleet boots from a 29GB eMMC with a 13GB root and keeps application
%% data on its `/bulk' drives, so the compose file mounts one and sets this. The
%% default is what a laptop wants; a container without the mount loses the roster
%% on every recreate, which is the same as not keeping one.
%%
%% ⚠⚠ AND THE ISLAND'S IDENTITY LIVES IN THIS DIRECTORY TOO. `dronex_identity'
%% mints 128 bits here once and reads them for ever after, so a deployment that
%% forgets the mount does not merely lose the roster: the island becomes a NEW
%% island at every restart, and every fact it ever published is orphaned.
-spec data_dir() -> string().
data_dir() -> chosen(os:getenv("HECATE_DRONEX_DATA_DIR")).

chosen(false) -> "/tmp/hecate_dronex";
chosen("") -> "/tmp/hecate_dronex";
chosen(Path) -> Path.
