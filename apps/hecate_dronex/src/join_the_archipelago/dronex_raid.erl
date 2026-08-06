%% @doc What a raid looks like on the wire, and what it refuses. PURE.
%%
%% THIS EXISTS SO TWO ISLANDS CAN FIGHT WITHOUT EITHER OF THEM TRUSTING THE OTHER.
%%
%% ==========================================================================
%% ⚠ THE WHOLE RAID REFUSES, NEVER ONE ENTRANT
%% ==========================================================================
%%
%% `DESIGN_WHAT_CROSSES_THE_MESH.md' is explicit and the reason is worth keeping
%% next to the code: a genome with a wrong-width input layer does NOT crash. The
%% evaluator pads a short input in silence and a short output vector falls back
%% to a null command, so a mismatched entrant flies badly and produces a result
%% that looks exactly like a real one. There is no error to notice.
%%
%% So every genome is validated BEFORE the engagement starts, never during, and a
%% single failure refuses the whole raid. A refused raid is a fact; a raid with
%% one silently crippled drone in it is a lie.
%%
%% ==========================================================================
%% ⚠⚠ AND THE ENGINE FINGERPRINT IS THE SAME ARGUMENT ONE LEVEL UP
%% ==========================================================================
%%
%% Two islands on different builds produce results comparable to nothing. The
%% sibling shipped precisely that — the site pinned one engine commit and the
%% service pinned another — and the only thing between it and drawing a fight
%% nobody fought was a turn-count self-check.
%%
%% What goes into the fingerprint is everything that would change an outcome
%% without changing an interface:
%%
%%   the PHYSICS      every constant `airspace:limits/0' reports. CHARTER.md
%%                    rule 2 says physics ships with the image, so two images
%%                    with different constants must not be able to fight
%%   the GENOME SHAPE topology, weight count, tau count. A genome that is a
%%                    valid vector of the wrong length is the failure above
%%   the SENSES       channel count and comms width, which decide what an
%%                    input vector even means
%%   the RUNTIME      OTP release, ERTS version and system architecture. The
%%                    architecture string carries the libc, and a run is only a
%%                    pure function of its seed within ONE OTP release: `rand'
%%                    is documented as free to change its algorithms between
%%                    them, which is exactly the kind of difference that shows
%%                    up as a plausible fight rather than as an error
-module(dronex_raid).

-export([fingerprint/0, fingerprint_parts/0]).
-export([request/4, accepted/1, decode_request/1, decode_reply/1]).
-export([validate_request/2, protocol_version/0, procedure/1]).
-export([muster_timeout_ms/0, call_timeout_ms/0]).

-export_type([sortie/0, fate/0]).

%% Bumped when the SHAPE of these maps changes. Distinct from the fingerprint,
%% which changes when the WORLD changes: two islands can share a protocol
%% version and still be unable to fight.
-define(PROTOCOL_VERSION, 1).

%% A raid is addressed to one island by its identity, because there is no
%% directory. An attacker learns an island_id from the public realm — the only
%% place islands become visible to each other — and calls this procedure on the
%% FLEET realm, which is why a stranger cannot start a fight.
-define(PROC_PREFIX, <<"dronex.raid.">>).

%% ==========================================================================
%% ⚠ TWO TIMEOUTS, AND THE ORDER BETWEEN THEM IS THE CORRECTNESS CONDITION
%% ==========================================================================
%%
%% The handshake is: the caller CALLs, the callee validates the request and asks
%% its own island for a defending party, and answers. Both are fast, and the
%% fight is spawned AFTER the answer goes back, so neither number has anything to
%% do with the length of an engagement.
%%
%% ⚠ THE CALLER'S BOUND MUST EXCEED THE CALLEE'S, and this is not tidiness. If a
%% caller gives up while a slow-but-living defender is still deciding, the
%% defender goes on to accept, publish its commitment and fight, while the
%% attacker treats the raid as refused and puts its party BACK in the roster
%% (`handshook, refused' does exactly that). The archipelago then holds a
%% recording of twelve drones that, according to their own island, never left.
%%
%% Ordered as they are, a caller timeout can only mean the message never landed,
%% because a defender that is merely slow times out its own muster first and
%% answers with an explicit error.
%%
%% Both are SHORT on purpose. A timeout costs nothing but a skipped raid: the
%% party stays home and the next raid timer comes round in two minutes. A LONG
%% timeout is what costs, because it holds a process and twelve packed genomes
%% for its whole duration against a target that may simply be gone.
-define(MUSTER_TIMEOUT_MS, 5000).
-define(CALL_TIMEOUT_MS, 10000).

%% @doc How long a defender may take to validate and muster before it refuses.
-spec muster_timeout_ms() -> pos_integer().
muster_timeout_ms() -> ?MUSTER_TIMEOUT_MS.

%% @doc How long an attacker waits for the handshake. Must exceed
%% `muster_timeout_ms/0'; see the note above for what happens when it does not.
-spec call_timeout_ms() -> pos_integer().
call_timeout_ms() -> ?CALL_TIMEOUT_MS.

-type sortie() :: #{id := binary(), genome := binary()}.
-type fate() :: survived | lost.

-spec protocol_version() -> pos_integer().
protocol_version() -> ?PROTOCOL_VERSION.

%% @doc The procedure a defender advertises, and an attacker calls.
-spec procedure(binary()) -> binary().
procedure(IslandId) when is_binary(IslandId) ->
    <<?PROC_PREFIX/binary, IslandId/binary>>.

%%==============================================================================
%% The fingerprint
%%==============================================================================

%% @doc 32 bytes over everything that would change an outcome silently.
%%
%% ⚠⚠⚠ `[deterministic]' IS LOad BEARING AND ITS ABSENCE MADE THIS A FINGERPRINT
%% THAT DID NOT IDENTIFY ANYTHING. `term_to_binary/1' does not encode a map
%% canonically: for a map big enough to be a hashmap — `airspace:limits/0' has
%% about thirty-five keys — the entries are emitted in internal hash order, and
%% for ATOM keys that order depends on the node's atom table, which depends on
%% the order atoms were first created. Two islands running the identical image
%% therefore produced different fingerprints, measured:
%%
%%     physics, plain           beam01 AB9CD351   beam02 8BF316FD
%%     physics, deterministic   beam01 41BF0006   beam02 41BF0006
%%
%% Every other part matched. The consequence was total and silent: each island
%% filtered the other out of its target list as an incompatible engine, so no
%% raid was ever attempted, `raids' stayed at zero on both, and nothing anywhere
%% reported an error — the mechanism simply did not run.
%%
%% ⚠ AND IT FAILS IN THE DIRECTION THAT LOOKS LIKE CAUTION. A fingerprint exists
%% to refuse mismatched engines; one that is wrong refuses everything, which
%% reads as the check working rather than as the check being broken.
-spec fingerprint() -> binary().
fingerprint() -> crypto:hash(sha256, term_to_binary(fingerprint_parts(), [deterministic])).

%% @doc The parts, so a mismatch can be explained rather than merely reported.
%%
%% ⚠ EXPORTED BECAUSE `REFUSED' IS USELESS ON ITS OWN. Two islands that cannot
%% fight need to know WHICH of physics, genome shape, senses or runtime differs,
%% and a hash cannot say. This is what an operator reads after a refusal.
-spec fingerprint_parts() -> map().
fingerprint_parts() ->
    #{physics => airspace:limits(),
      topology => drone_genome:topology(),
      genes => drone_genome:gene_count(drone_genome:layers()),
      senses => drone_senses:channels(),
      comms => drone_senses:comms_width(),
      otp => list_to_binary(erlang:system_info(otp_release)),
      erts => list_to_binary(erlang:system_info(version)),
      arch => list_to_binary(erlang:system_info(system_architecture))}.

%%==============================================================================
%% The request
%%==============================================================================

%% @doc What an attacker sends. The genomes are already packed: `drone_genome:pack/1'
%% is the canonical form the id is the hash of, so what travels is byte for byte
%% what the id names.
-spec request(binary(), binary(), [sortie()], non_neg_integer()) -> map().
request(IslandId, RaidId, Sorties, Tick) ->
    #{protocol => ?PROTOCOL_VERSION,
      fingerprint => fingerprint(),
      attacker => IslandId,
      raid_id => RaidId,
      tick => Tick,
      sortie => [#{id => Id, genome => G} || #{id := Id, genome := G} <- Sorties]}.

-spec decode_request(term()) -> {ok, map()} | {error, term()}.
decode_request(#{protocol := V, fingerprint := F, attacker := A,
                 raid_id := R, sortie := S} = Req)
  when is_integer(V), is_binary(F), is_binary(A), is_binary(R), is_list(S) ->
    {ok, Req#{tick => maps:get(tick, Req, 0)}};
decode_request(_Malformed) ->
    {error, malformed_request}.

%%==============================================================================
%% What a defender refuses, and in which order
%%==============================================================================

%% @doc Everything checked before a single tick is simulated.
%%
%% ⚠ THE ORDER IS THE ERROR MESSAGE. Protocol first, because a version mismatch
%% explains every later failure and reporting a genome error to an island running
%% a different protocol would send it looking in the wrong place. Fingerprint
%% next, for the same reason one level down. Genomes last, because they are the
%% only check that is per-entrant and the only one worth naming an index for.
-spec validate_request(map(), pos_integer()) -> ok | {error, term()}.
validate_request(#{protocol := V}, _Cap) when V =/= ?PROTOCOL_VERSION ->
    {error, {protocol_mismatch, V, ?PROTOCOL_VERSION}};
validate_request(#{fingerprint := F} = Req, Cap) ->
    engine_checked(F =:= fingerprint(), F, Req, Cap);
validate_request(_Req, _Cap) ->
    {error, no_fingerprint}.

engine_checked(false, Theirs, _Req, _Cap) ->
    {error, {engine_mismatch, Theirs, fingerprint()}};
engine_checked(true, _Theirs, #{sortie := S}, Cap) ->
    sized(length(S), Cap, S).

%% ⚠ A CAP, AND IT IS NOT POLITENESS. A raid arrives from a stranger and every
%% entrant costs an unpack, a validation and a controller. Without a bound, one
%% call decides how much work this island does, and the honest name for that is
%% somebody else's for loop running here.
sized(0, _Cap, _S) -> {error, empty_sortie};
sized(N, Cap, _S) when N > Cap -> {error, {sortie_too_large, N, Cap}};
sized(_N, _Cap, S) -> every_genome(S, 0).

%% ⚠ EVERY ONE, AND THE INDEX TRAVELS WITH THE ERROR. This is the only per-entrant
%% check, so it is the only one where "which" is answerable, and a refusal that
%% cannot say which genome was wrong sends the sender looking through all of them.
every_genome([], _I) -> ok;
every_genome([#{id := Id, genome := Packed} | Rest], I) when is_binary(Id), is_binary(Packed) ->
    unpacked(drone_genome:unpack(Packed), Id, Packed, Rest, I);
every_genome([_Malformed | _Rest], I) ->
    {error, {malformed_entrant, I}}.

unpacked({error, Why}, _Id, _Packed, _Rest, I) -> {error, {unpackable, I, Why}};
unpacked({ok, G}, Id, Packed, Rest, I) -> flyable(drone_genome:validate(G), G, Id, Packed, Rest, I).

flyable({error, Why}, _G, _Id, _Packed, _Rest, I) -> {error, {invalid_genome, I, Why}};
flyable(ok, G, Id, Packed, Rest, I) -> named(drone_genome:id(G), Id, Packed, Rest, I).

%% ⚠ THE ID MUST BE THE HASH OF WHAT ARRIVED. An id is `sha256' of the packed
%% genome, and this is the whole reason the packed form travels rather than a
%% term: if a sender could name a genome anything, the defender's opponent set
%% and the raid record would disagree about what actually flew, and nothing
%% downstream could tell.
named(Id, Id, _Packed, Rest, I) -> every_genome(Rest, I + 1);
named(Real, Claimed, _Packed, _Rest, I) -> {error, {id_mismatch, I, Claimed, Real}}.

%%==============================================================================
%% The reply
%%==============================================================================

%% @doc The whole of what the defender says synchronously: yes, I have taken your
%% raid, and a defence is already in the air.
%%
%% ⚠ THE CALL IS A HANDSHAKE AND NOTHING MORE. It used to carry the outcome and
%% every genome's fate, which meant the caller was blocked for the length of an
%% engagement and `dronex_mesh:call/2' needed a 120-second timeout with a comment
%% explaining that five seconds would report failure for a raid going perfectly.
%% A call whose timeout has to cover the callee's real work is doing two jobs.
%%
%% ⚠⚠ WHAT IT IS STILL FOR IS ADMISSION CONTROL, AND THAT IS WHY IT IS NOT
%% PUB/SUB. Two attackers both see an island open, both muster, both send. Only a
%% synchronous answer can turn one of them away BEFORE it has committed a party,
%% and a committed party is the entire price of a raid. Every refusal is
%% instant — wrong protocol, wrong engine, bad genome, nobody left to field — so
%% the timeout can go back to being a real one.
%%
%% ⚠⚠⚠ AND IT DID NOT, FOR MONTHS. The paragraph above was written when the
%% protocol changed and the constant was left at 120 seconds, with a comment in
%% `dronex_mesh' still explaining that the callee was fighting. Two comments in
%% one repository, each describing a different design, and the stale one was
%% attached to the number that actually ran. Measured on beam03, 2026-08-06: a
%% target whose route was dead cost the attacker two minutes of a blocked process
%% per attempt, about every two minutes, all day.
%%
%% The outcome arrives later, as a fact, on `dronex/raid_settled'.
-spec accepted(binary()) -> map().
accepted(RaidId) ->
    #{protocol => ?PROTOCOL_VERSION, raid_id => RaidId, accepted => true}.

-spec decode_reply(term()) -> {ok, map()} | {error, term()}.
decode_reply(#{protocol := V, raid_id := R, accepted := true} = Reply)
  when is_integer(V), is_binary(R) ->
    handshook(V =:= ?PROTOCOL_VERSION, Reply, V);
decode_reply({error, _} = E) ->
    E;
decode_reply(_Malformed) ->
    {error, malformed_reply}.

handshook(true, Reply, _V) -> {ok, Reply};
handshook(false, _Reply, V) -> {error, {protocol_mismatch, V, ?PROTOCOL_VERSION}}.
