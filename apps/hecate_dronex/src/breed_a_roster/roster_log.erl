%% @doc The roster's durable record: what this island bred, and when.
%%
%% THIS EXISTS SO AN ISLAND IS NOT A RECORDING OF ITS OWN FIRST TEN MINUTES.
%% A trained swarm is expensive to produce, and one that vanishes on every
%% container recreate is a demo rather than a lineage.
%%
%% ==========================================================================
%% AN EVENT STREAM, NOT A FILE, AND THE PROVENANCE IS THE REASON
%% ==========================================================================
%%
%% `CHARTER.md' makes a raid the way opponent diversity crosses the mesh, so
%% "where did this controller come from" is the archipelago's central question.
%% A file holding the current roster answers it for today and forgets yesterday.
%% A stream of admissions keeps the whole descent, and every entry carries its
%% parents, its generation, its origin and what it has survived.
%%
%% ==========================================================================
%% ⚠ SNAPSHOT PLUS TAIL, BECAUSE A REPLAY THAT GROWS WITHOUT BOUND IS A BOOT
%% THAT EVENTUALLY DOES NOT FINISH
%% ==========================================================================
%%
%% A trainer that admits once a second writes 86,000 events a day. Folding all of
%% them at boot is fine for a week and not fine for a year, and the failure mode
%% is a node that takes longer to start every time until somebody notices.
%%
%% So the whole roster is written periodically as one `roster_snapshotted' event,
%% and restore reads BACKWARD to the most recent one and then forward from there.
%% The admissions before it are still in the stream and still readable; they are
%% simply not on the boot path.
%%
%% ==========================================================================
%% ⚠⚠⚠ THE THREE SENTENCES ABOVE WERE FALSE FROM THE DAY THEY WERE WRITTEN,
%% AND EVERY ISLAND STARTED ITS LIFE AGAIN ON EVERY DEPLOY
%% ==========================================================================
%%
%% Measured on beam01 on 2026-08-07: a stream 1,111 events deep, a roster of 229
%% in memory, and `restore/2' returning `{error, {restore_failed, error,
%% {badmap, {event, ...}}}}'. It had never once succeeded.
%%
%% Three separate faults, and each one hid the next:
%%
%%   1. `reckon_gater_api:stream_forward/4' returns `#event{}' RECORDS. This
%%      module called `maps:find/2' on them, under a comment asserting that
%%      events "come back from the gater as maps whose keys may be atoms or
%%      binaries". They are neither shape. The first event of the first restore
%%      raised `badmap' and no restore ever got past it.
%%   2. `island_server:kept/2' matched `{error, _Why}' and returned the island
%%      unchanged, SILENTLY. A fresh roster filling up from seed looks exactly
%%      like a restored one, so the only published evidence agreed with both.
%%   3. Restore read `stream_forward(_, _, 0, 5000)': forward from the beginning,
%%      capped. Not the backward scan described here. The cap had not bitten yet
%%      at 1,111 events and would have, silently, at 5,000.
%%
%% What it cost: every counter on the island, the tick, and the lineage itself,
%% on every container recreate since this module was written. `D.15' in
%% `REGISTER.md' asks why the frozen exam swings a hundred points in a day on a
%% bred champion. One candidate is now that the champion was bred from scratch.
-module(roster_log).

-export([stream/0, snapshot/3, snapshot/4, admitted/2, evicted/2]).
-export([restore/1, restore/2]).
-export([rebuild/2]).

%% ⚠ A SYSTEM STREAM, AND THE FORMAT IS A CONTRACT RATHER THAN A PREFERENCE.
%% This was `roster', which reckon-db rejects: `reckon_gater_stream_id' accepts
%% exactly two shapes, a user stream `<prefix>-<32 lowercase hex>' or a system
%% stream `$<namespace>:<name>'. A bare word is neither.
%%
%% ⚠⚠ AND IT DID NOT FAIL LIKE A VALIDATION ERROR. The rejection is RAISED from
%% `reckon_db_stream_path:id_nodes/1' as an exit rather than returned, so
%% `reckon_gater_retry' could not match it against its own non-retriable
%% whitelist and retried eleven times with exponential backoff, for about four
%% minutes, inside the island's process. See `roster_log_writer'.
%%
%% ==========================================================================
%% ⚠⚠⚠⚠ `_g2' IS A DELIBERATE FLEET WIPE, 2026-08-09. CHANGING IT BACK RESURRECTS
%% A LINEAGE BRED UNDER PHYSICS THAT NO LONGER EXIST
%% ==========================================================================
%%
%% The guided weapon went from 600 m of reach to 60 m and from four rounds to
%% two, and engagements now open 800 m apart instead of 400 m. Every genome in
%% the `$dronex:roster' stream was bred against the old ones, and every invader
%% archived there was captured under them. Their fitness numbers are not merely
%% stale, they were earned in a different game.
%%
%% So the lineage starts empty rather than being migrated. A new stream NAME does
%% that without destroying anything: the old stream stays in every store, intact
%% and readable, and nothing reads it. That also means the wipe ships in the image
%% through CI and watchtower like any other change, with no ssh to any box and no
%% `rm' anywhere near a store.
%%
%% ⚠ AND `_g2' IS AN UNDERSCORE BECAUSE A SECOND COLON DOES NOT PARSE. Verified
%% against `reckon_db_stream_path:stream_path/1' before shipping:
%%
%%   $dronex:roster        ->  {ok, [streams, <<"$dronex">>, <<"roster">>]}
%%   $dronex:roster:g2     ->  {error, {invalid_stream_id, ...}}
%%   $dronex:roster_g2     ->  {ok, [streams, <<"$dronex">>, <<"roster_g2">>]}
%%
%% The obvious name is the broken one. Worse, the paragraph below records what
%% that failure looks like from here: an exit rather than a return, which
%% `reckon_gater_retry' cannot match against its non-retriable list, so it retries
%% eleven times with backoff for about four minutes INSIDE the island process. On
%% five islands at once, on a deploy, that is a fleet-wide stall caused by a
%% punctuation choice. `roster_log_tests' now checks the name parses.
%%
%% A SYSTEM stream rather than a user one, because this is a singleton per store
%% and system streams exist for exactly that operational legibility. A user
%% stream would need 32 hex digits of identity for a thing there is only ever one
%% of, and the store is already per-island.
%% ⚠⚠ AND `_g3' FROM 2026-08-10, FOR THE SAME REASON AT A DIFFERENT LAYER. The
%% weapon did not change this time; the SEARCH did. `breed:random/1' drew every
%% seeded time constant into [0.406, 0.644], a quarter of what `to_tau/1'
%% expresses, and one sigma in gene units moved a tau at a quarter of a weight's
%% pace through a range four times larger. Measured over all five rosters, 452
%% entries and 10,848 time constants: not one was fast or slow, after 150
%% generations. Seeding now draws taus across the whole range and the step is
%% scaled to match, and `trainer' seats a child while the roster has room instead
%% of turning it away.
%%
%% Both change the distribution a lineage starts from and the rate it moves at, so
%% a `_g2' genome and a `_g3' genome were not produced by the same process and
%% their fitness numbers are not comparable. Same mechanism as before: a new name,
%% the old streams intact and unread, no ssh and no `rm' near a store.
-define(STREAM, <<"$dronex:roster_g3">>).

%% How far back `restore/1' will look for a snapshot before giving up and
%% starting from nothing. Generous, because the cost is paid once at boot and the
%% alternative is silently losing a lineage.
-define(SCAN_LIMIT, 5000).

%% Events per read. The backward scan walks pages until it finds a snapshot; the
%% forward replay walks pages until the stream ends. Neither is capped at a total
%% any more, so a stream that outgrows one page cannot quietly restore an old
%% state — which is what the previous `stream_forward(_, _, 0, 5000)' would have
%% done the moment the stream passed five thousand.
-define(PAGE, 500).

%% ⚠ THE EVENT IS A RECORD AND THE HEADER IS THE ONLY PLACE THAT KNOWS ITS SHAPE.
%% This module previously guessed, guessed maps, and was wrong for its whole life.
%% `element(3, Ev)' would work today and would be the same guess again.
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-spec stream() -> binary().
stream() -> ?STREAM.

%%==============================================================================
%% Writing
%%==============================================================================

%% @doc Write the whole roster, and the tally of what the lineage has done.
%%
%% ⚠ THE TALLY RIDES WITH THE ROSTER RATHER THAN IN ITS OWN EVENT, because the
%% two are one fact: this population, having done these things. Two events would
%% be two writes that can succeed separately, and a restored roster paired with
%% somebody else's counters is worse than either alone.
%%
%% It is opaque here. `island' owns what the keys mean; this module stores what
%% it is handed and gives it back, so a counter can be added there without a
%% change to the durable format.
-spec snapshot(atom(), roster:roster(), map()) -> ok | {error, term()}.
snapshot(StoreId, R, Tally) -> snapshot(StoreId, R, Tally, invaders:new()).

%% @doc As above, and the invader archive with it.
%%
%% ⚠ ONE SNAPSHOT AND ONE STREAM, NOT TWO. The archive could have had its own log
%% and its own restore, and the reason it does not is `REGISTER I.21': this
%% restore path had THREE faults hiding each other and had never once succeeded,
%% for the whole life of the track. A second copy of the same subtle machinery is
%% a second place for the same three faults to live.
%%
%% ⚠⚠ AND THEY MUST BE RESTORED TOGETHER OR NOT AT ALL. The archive's eras are
%% measured against the island's own tick, which arrives in the tally beside it.
%% A roster restored with an archive from a different write would date every
%% invader against the wrong clock.
-spec snapshot(atom(), roster:roster(), map(), invaders:archive()) ->
    ok | {error, term()}.
snapshot(StoreId, R, Tally, Archive) when is_map(Tally) ->
    append(StoreId, <<"roster_snapshotted">>,
           #{entries => [packed(E) || E <- roster:entries(R)],
             capacity => roster:capacity(R),
             tally => Tally,
             invaders => [packed_invader(I) || I <- invaders:entries(Archive)],
             invader_capacity => invaders:capacity(Archive)}).

packed_invader(I) ->
    #{id => invaders:entry_id(I),
      genome => drone_genome:pack(invaders:entry_genome(I)),
      from => invaders:entry_from(I),
      raid => invaders:entry_raid(I),
      seen_at => invaders:entry_seen_at(I)}.

%% @doc Record one admission, with everything needed to rebuild it.
-spec admitted(atom(), roster:entry()) -> ok | {error, term()}.
admitted(StoreId, E) -> append(StoreId, <<"genome_admitted">>, packed(E)).

-spec evicted(atom(), binary()) -> ok | {error, term()}.
evicted(StoreId, Id) -> append(StoreId, <<"genome_evicted">>, #{id => Id}).

%% ⚠ A WRITE THAT CANNOT HAPPEN IS AN ERROR THE CALLER SHRUGS AT, NOT AN EXIT.
%% The store is a gen_server behind a registry, so before it is up these calls do
%% not return an error: they EXIT. Unwrapped, that exit travels up through the
%% trainer timer and kills the island, losing the roster it was trying to save,
%% which is the exact opposite of what this module is for.
append(StoreId, Type, Payload) ->
    try written(reckon_gater_api:append_events(StoreId, ?STREAM, [event(Type, Payload)]))
    catch Class:Reason -> {error, {append_failed, Class, Reason}}
    end.

written({ok, _Version}) -> ok;
written({error, _} = E) -> E;
written(Other) -> {error, {unexpected, Other}}.

event(Type, Payload) ->
    #{event_type => Type, data => Payload, metadata => #{}}.

%% ⚠ THE GENOME IS PACKED, NOT STORED AS A TERM. `drone_genome:pack/1' is the
%% canonical form the id is the hash of, so what is written down is byte for byte
%% what a raid would send and what an id identifies. Storing the tuple and packing
%% it later would be two representations of one thing, and the day they disagree
%% the stored id stops naming the stored genome.
packed(E) ->
    #{id => roster:entry_id(E),
      genome => drone_genome:pack(roster:entry_genome(E)),
      generation => roster:entry_generation(E),
      fitness => roster:entry_fitness(E),
      origin => roster:entry_origin(E),
      sorties => roster:entry_sorties(E)}.

%%==============================================================================
%% Reading
%%==============================================================================

%% @doc Rebuild the roster and the tally from the store.
%%
%% The tally is `#{}' when the newest snapshot predates it, which is every
%% snapshot written before 2026-08-07. An absent tally is not a tally of zero:
%% `island:with_tally/2' takes the larger of stored and live, so an old snapshot
%% leaves the counters where they are rather than winding them back.
-spec restore(atom()) ->
    {ok, roster:roster(), map(), invaders:archive()} | {error, term()}.
restore(StoreId) -> restore(StoreId, roster:new(restored)).

%% ⚠ FOUR ELEMENTS NOW, AND THE ARCHIVE IS EMPTY RATHER THAN ABSENT WHEN A
%% SNAPSHOT PREDATES IT. An island restoring from a store written before the
%% archive existed gets `invaders:new()', which is the same shape it would have
%% on a fresh boot, so nothing downstream needs to know which happened.
-spec restore(atom(), roster:roster()) ->
    {ok, roster:roster(), map(), invaders:archive()} | {error, term()}.
restore(StoreId, Empty) ->
    try folded(read_from(StoreId, newest_snapshot(StoreId)), Empty)
    catch Class:Reason -> {error, {restore_failed, Class, Reason}}
    end.

%%------------------------------------------------------------------------------
%% Finding where to start: backward to the newest snapshot
%%------------------------------------------------------------------------------

%% The version of the most recent `roster_snapshotted', or 0 to replay the whole
%% stream when there is none within ?SCAN_LIMIT. Replaying everything is correct
%% and merely slow; starting after a snapshot that was never found would be fast
%% and wrong.
newest_snapshot(StoreId) -> from_version(reckon_gater_api:get_version(StoreId, ?STREAM), StoreId).

from_version({ok, V}, StoreId) when is_integer(V), V >= 0 -> scan_back(StoreId, V, 0);
from_version(_Unknown, _StoreId) -> 0.

scan_back(_StoreId, From, Scanned) when From < 0; Scanned >= ?SCAN_LIMIT -> 0;
scan_back(StoreId, From, Scanned) ->
    stepped(reckon_gater_api:stream_backward(StoreId, ?STREAM, From, ?PAGE),
            StoreId, From, Scanned).

stepped({ok, []}, _StoreId, _From, _Scanned) -> 0;
stepped({ok, Evs}, StoreId, From, Scanned) -> newest_of(snapshots(Evs), StoreId, From, Scanned, Evs);
stepped(_Other, _StoreId, _From, _Scanned) -> 0.

%% ⚠ `lists:max', NOT the head. Whether a backward read returns its page newest
%% first or oldest first is not promised anywhere, and taking the head would
%% restore a snapshot one page stale on half the possible implementations.
newest_of([], StoreId, From, Scanned, Evs) ->
    scan_back(StoreId, From - length(Evs), Scanned + length(Evs));
newest_of(Versions, _StoreId, _From, _Scanned, _Evs) -> lists:max(Versions).

snapshots(Evs) -> [version_of(E) || E <- Evs, type_of(E) =:= <<"roster_snapshotted">>].

%%------------------------------------------------------------------------------
%% Replaying forward from there, to the end
%%------------------------------------------------------------------------------

read_from(StoreId, Version) -> pages(StoreId, Version, []).

pages(StoreId, From, Acc) ->
    paged(reckon_gater_api:stream_forward(StoreId, ?STREAM, From, ?PAGE), StoreId, From, Acc).

%% A full page means there may be more; a short one is the end of the stream.
%% That is the termination condition, and it is the reason nothing here counts
%% up to a limit it could silently hit.
paged({ok, Evs}, StoreId, From, Acc) when length(Evs) =:= ?PAGE ->
    pages(StoreId, From + ?PAGE, lists:reverse(Evs, Acc));
paged({ok, Evs}, _StoreId, _From, Acc) -> {ok, lists:reverse(lists:reverse(Evs, Acc))};
paged({error, _} = E, _StoreId, _From, _Acc) -> E;
paged(Other, _StoreId, _From, _Acc) -> {error, {unexpected, Other}}.

%% Every shape the reader can hand back is already normalised by `paged/4', so
%% there is no third clause here and dialyzer is the one who says so.
folded({error, _} = E, _Empty) -> E;
folded({ok, Events}, Empty) -> restored_pair(rebuild(Events, Empty)).

restored_pair({R, Tally, Archive}) -> {ok, R, Tally, Archive}.

%% @doc Interpret a list of stored events into a roster and a tally.
%%
%% ⚠ PUBLIC BECAUSE THE READING IS THE PART THAT WAS WRONG, and a seam that takes
%% events and returns state can be tested without a store, a node or a network.
%% There was no such seam, so there was no such test, so `restore/2' shipped
%% raising `badmap' on its first event and stayed that way for weeks.
-spec rebuild([#event{}], roster:roster()) ->
    {roster:roster(), map(), invaders:archive()}.
rebuild(Events, Empty) ->
    lists:foldl(fun apply_event/2, {Empty, #{}, invaders:new()}, Events).

%% ⚠ AN EVENT THAT CANNOT BE UNDERSTOOD IS SKIPPED, NOT FATAL. A store written by
%% a later version of this island will hold event types this one has never heard
%% of, and refusing to boot on one of them turns a rollback into an outage. The
%% cost is that a rolled-back island holds less than it could, which is visible
%% in its published roster depth.
apply_event(Ev, Acc) -> replay(type_of(Ev), data_of(Ev), Acc).

%% A snapshot REPLACES. It is full state, so whatever was folded before it is
%% superseded, tally included.
replay(<<"roster_snapshotted">>, #{entries := Es} = D, _Acc) ->
    {roster:restore(rebuilt_all(Es)), tally_in(D), archive_in(D)};
replay(<<"genome_admitted">>, Packed, {R, T, A}) -> {readmit(unpacked(Packed), R), T, A};
replay(<<"genome_evicted">>, #{id := Id}, {R, T, A}) -> {roster:evict(R, Id), T, A};
replay(_Unknown, _Data, Acc) -> Acc.

%% ⚠ A SNAPSHOT FROM BEFORE THE ARCHIVE EXISTED HAS NO `invaders' KEY, and that
%% is an empty archive rather than a crash. Islands roll one at a time and a
%% rollback must not be an outage.
archive_in(D) -> witnessed_all(maps:get(invaders, D, []), fresh_archive(D)).

fresh_archive(D) ->
    case maps:get(invader_capacity, D, undefined) of
        N when is_integer(N), N > 0 -> invaders:new(N);
        _absent -> invaders:new()
    end.

witnessed_all(Packed, A) ->
    lists:foldl(fun (P, Acc) -> witnessed_one(P, Acc) end, A, Packed).

witnessed_one(#{genome := Bin} = P, A) ->
    revived(drone_genome:unpack(Bin), P, A);
witnessed_one(_Other, A) -> A.

%% ⚠ THE ORIGINAL `seen_at' IS RESTORED, WHICH IS THE ENTIRE POINT OF PERSISTING
%% THIS AT ALL. Witnessing them at the restore moment would date every invader to
%% the boot and collapse every era into one, so the archive would say the island
%% has only ever faced things from this morning — which is exactly the blindness
%% the archive exists to remove.
revived({error, _Why}, _P, A) -> A;
revived({ok, Genome}, P, A) ->
    invaders:witness(A, Genome,
                     maps:get(from, P, <<"unknown">>),
                     maps:get(raid, P, <<"unknown">>),
                     maps:get(seen_at, P, 0)).

%% Unpacked ONCE per entry. The previous version called `unpacked/1' twice for
%% every genome in the snapshot, once in the filter and once in the body, which
%% doubled the CPU of the boot path for nothing.
rebuilt_all(Es) -> [E || E <- [unpacked(P) || P <- Es], E =/= undefined].

tally_in(D) -> counted(maps:get(tally, D, #{})).

counted(M) when is_map(M) -> M;
counted(_Other) -> #{}.

readmit(undefined, R) -> R;
readmit(E, R) -> kept(roster:admit(R, E), R).

kept({admitted, R}, _Was) -> R;
kept({refused, _Why}, Was) -> Was.

%% A genome that will not unpack is dropped rather than crashing the boot, for
%% the same reason an unknown event type is: a corrupt entry costs one controller
%% and a refusal to start costs the island.
unpacked(#{genome := Bin} = P) -> rebuilt(drone_genome:unpack(Bin), P);
unpacked(_Other) -> undefined.

rebuilt({error, _Why}, _P) -> undefined;
rebuilt({ok, Genome}, P) ->
    roster:entry(Genome,
                 #{generation => maps:get(generation, P, 0),
                   fitness => maps:get(fitness, P, 0),
                   origin => maps:get(origin, P, unknown)}).

%% ⚠ THE RECORD, FROM THE HEADER THE LIBRARY PUBLISHES. What stood here was a
%% map reader under a comment explaining why it accepted two key shapes, and the
%% events are records: `#event{event_id, event_type, stream_id, version, data,
%% metadata, ...}'. Both key shapes were wrong, the comment made the wrongness
%% look considered, and `maps:find/2' on a tuple raised `badmap' on the first
%% event of every restore this island ever attempted.
type_of(#event{event_type = T}) -> T.

version_of(#event{version = V}) -> V.

%% ⚠ A PAYLOAD THAT IS NOT A MAP FAILS THE RESTORE, IT IS NOT SKIPPED.
%% `#event.data' is typed `map() | binary()' and a binary would arrive from a
%% store written with a JSON content type. Returning `#{}' for one would make the
%% snapshot clause not match, fall through to the catch-all, and lose the whole
%% roster in silence — which is the exact failure mode this module has just spent
%% its entire life in. Loud is the only acceptable behaviour here.
%% ⚠⚠ AND THE REASON NAMES THE PAYLOAD RATHER THAN CARRYING IT. Register `I.18':
%% one refused raid wrote 18 MB into the log because a failure reason held twelve
%% packed genomes. A snapshot payload is larger than that.
%% `#event.data' is typed `map() | binary()', so those are the only two clauses
%% written. Anything else raises `function_clause', which is equally loud and does
%% not pretend to handle a shape the library says cannot occur.
data_of(#event{data = D}) when is_map(D) -> D;
data_of(#event{event_type = T, data = D}) when is_binary(D) ->
    error({payload_not_a_map, T, {binary, byte_size(D)}}).
