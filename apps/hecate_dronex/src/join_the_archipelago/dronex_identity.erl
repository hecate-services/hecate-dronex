%% @doc WHICH ISLAND THIS IS, AND WHAT IT IS CALLED. They are not the same thing.
%%
%% Ported from the sibling services, where the distinction was learned rather
%% than designed.
%%
%% ==========================================================================
%% AN ISLAND'S NAME IS NOT ITS IDENTITY
%% ==========================================================================
%%
%% `island/0' is a LABEL. It comes from an environment variable, falls back to
%% the hostname, and an operator types it. Two islands can carry the same one,
%% and in an archipelago of machines run by strangers they eventually will. Four
%% things break when they do:
%%
%%   - A SPECTATOR MERGES THEM. Facts filed under the name mean two islands
%%     called `beam01' overwrite each other, and the map shows one island
%%     flickering between two rosters.
%%   - THEY LAND ON ONE SQUARE, because a derived layout hashes what it is
%%     given, so one of them is simply invisible.
%%   - A RAID BECOMES AMBIGUOUS. "Send this sortie to beam01" can deliver it to
%%     the wrong island, lose it, or deliver it twice.
%%   - AND IT IS NOT ONLY AN ACCIDENT. Anyone may type your island's name into
%%     their own config and begin collecting your sorties.
%%
%% ⚠⚠ AND THE THIRD IS WORSE HERE THAN IT WAS ON A SIBLING. What crosses is a
%% GENOME, and a genome delivered twice is not an accounting error: it is one
%% controller counted as two in a roster whose whole point is that it is finite
%% and contested. CHARTER.md prices a raid in airframes, and a duplicated
%% airframe is free energy in an economy that is supposed to have none.
%%
%% So identity is `island_id/0', which nobody types, and the name is a nickname.
%% Two islands may both be called `beam01' exactly as two human beings may both
%% be called Raf.
-module(dronex_identity).

-export([island/0, island_id/0]).

%% @doc What this island is CALLED. Defaults to the host's name, because a
%% machine already has an identity and inventing a second one nobody configures
%% produces a fleet of islands all called "dronex".
-spec island() -> binary().
island() -> island_name(os:getenv("HECATE_DRONEX_ISLAND")).

island_name(false) -> hostname();
island_name("") -> hostname();
island_name(Str) -> list_to_binary(string:trim(Str)).

hostname() ->
    {ok, Host} = inet:gethostname(),
    list_to_binary(Host).

%% @doc WHICH ISLAND THIS IS, as against what it is called.
%%
%% 128 bits of randomness, minted once and kept in the data directory. Unique by
%% construction, so no two islands collide by accident however they are named,
%% and stable across restarts and redeploys because the fleet binds that
%% directory from the host.
%%
%% ⚠ THIS DEFEATS ACCIDENT AND NOT IMPERSONATION, and the difference is worth
%% stating rather than glossing over. Nothing signs this, so a node that wanted
%% to claim another island's identity could copy the file. Doing better needs the
%% mesh keypair, and `hecate_om' loads a stable one only when `identity_key_path'
%% is configured, which this service does not set: the pool's key is EPHEMERAL,
%% so an island keyed on it would become a NEW island at every restart. Binding
%% identity to a persisted keypair is named in CHARTER.md under what is owed.
%%
%% Read once and remembered, because a fact goes out on a timer and this must not
%% become a file read per publish.
-spec island_id() -> binary().
island_id() -> remembered(persistent_term:get({?MODULE, island_id}, undefined)).

remembered(undefined) ->
    Id = minted_or_read(),
    persistent_term:put({?MODULE, island_id}, Id),
    Id;
remembered(Id) ->
    Id.

minted_or_read() ->
    Path = filename:join(hecate_dronex_service:data_dir(), "island.id"),
    kept(file:read_file(Path), Path).

%% A file that exists and holds nothing usable is treated as absent rather than
%% trusted. A write torn by a crash would otherwise give this island a blank
%% identity for ever, which is the collision it exists to prevent.
kept({ok, Raw}, Path) -> usable(string:trim(Raw), Path);
kept({error, _Absent}, Path) -> mint(Path).

usable(<<Id:32/binary>>, _Path) -> Id;
usable(_Unusable, Path) -> mint(Path).

mint(Path) ->
    Id = binary:encode_hex(crypto:strong_rand_bytes(16), lowercase),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Id),
    Id.
