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
-module(roster_log).

-export([stream/0, snapshot/2, admitted/2, evicted/2, restore/1, restore/2]).

%% One stream per island. The store is already per-island, so a second name here
%% would be a distinction without a difference.
-define(STREAM, <<"roster">>).

%% How far back `restore/1' will look for a snapshot before giving up and
%% starting from nothing. Generous, because the cost is paid once at boot and the
%% alternative is silently losing a lineage.
-define(SCAN_LIMIT, 5000).

-spec stream() -> binary().
stream() -> ?STREAM.

%%==============================================================================
%% Writing
%%==============================================================================

%% @doc Write the whole roster as one event.
-spec snapshot(atom(), roster:roster()) -> ok | {error, term()}.
snapshot(StoreId, R) ->
    append(StoreId, <<"roster_snapshotted">>,
           #{entries => [packed(E) || E <- roster:entries(R)],
             capacity => roster:capacity(R)}).

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

%% @doc Rebuild the roster from the store, or an empty one if there is nothing.
-spec restore(atom()) -> {ok, roster:roster()} | {error, term()}.
restore(StoreId) -> restore(StoreId, roster:new(restored)).

-spec restore(atom(), roster:roster()) -> {ok, roster:roster()} | {error, term()}.
restore(StoreId, Empty) ->
    try folded(read_all(StoreId), Empty)
    catch Class:Reason -> {error, {restore_failed, Class, Reason}}
    end.

read_all(StoreId) -> reckon_gater_api:stream_forward(StoreId, ?STREAM, 0, ?SCAN_LIMIT).

folded({error, _} = E, _Empty) -> E;
folded({ok, Events}, Empty) -> {ok, lists:foldl(fun apply_event/2, Empty, Events)};
folded(Other, _Empty) -> {error, {unexpected, Other}}.

%% ⚠ AN EVENT THAT CANNOT BE UNDERSTOOD IS SKIPPED, NOT FATAL. A store written by
%% a later version of this island will hold event types this one has never heard
%% of, and refusing to boot on one of them turns a rollback into an outage. The
%% cost is that a rolled-back island holds less than it could, which is visible
%% in its published roster depth.
apply_event(Ev, R) -> replay(type_of(Ev), data_of(Ev), R).

replay(<<"roster_snapshotted">>, #{entries := Es}, _R) ->
    roster:restore([unpacked(P) || P <- Es, unpacked(P) =/= undefined]);
replay(<<"genome_admitted">>, Packed, R) -> readmit(unpacked(Packed), R);
replay(<<"genome_evicted">>, #{id := Id}, R) -> roster:evict(R, Id);
replay(_Unknown, _Data, R) -> R.

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

%% Events come back from the gater as maps whose keys may be atoms or binaries,
%% depending on how they were written and read. Both are accepted here rather
%% than assumed, because a shape mismatch would present as an empty roster and an
%% empty roster is indistinguishable from a fresh island.
type_of(Ev) -> pick(Ev, [event_type, <<"event_type">>], <<>>).
data_of(Ev) -> pick(Ev, [data, <<"data">>], #{}).

pick(Map, [K | Rest], Default) -> found(maps:find(K, Map), Map, Rest, Default);
pick(_Map, [], Default) -> Default.

found({ok, V}, _Map, _Rest, _Default) -> V;
found(error, Map, Rest, Default) -> pick(Map, Rest, Default).
