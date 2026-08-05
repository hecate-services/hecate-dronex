%% @doc The only module in this service that knows macula exists.
%%
%% Everything else takes and returns terms. When the transport changes, or when
%% these facts eventually move to a realm of their own, this is the file that
%% changes and nothing else does.
%%
%% Ported from the sibling services, where every paragraph below was paid for.
%%
%% A DARK MESH IS NOT A FAILURE OF THE ISLAND. An island whose neighbours are
%% unreachable is still an island: its trainer runs, its roster grows, its
%% benchmark is measured, and the only things lost are that nobody hears about it
%% and nobody attacks it. So a publish that cannot happen returns an error to a
%% caller that shrugs, rather than taking the island down with it. What must
%% never happen is silence that looks like success, which is why the error is a
%% return value and not a swallowed exception.
%%
%% FACTS GO OUT ON THEIR OWN REALM, AND THAT ASYMMETRY IS THE ACCESS CONTROL.
%% These facts are meant to be read by a public website, and handing a public web
%% container the fleet realm tag would let anything in that container read
%% sentinel sightings and warden facts too. The service keeps its fleet identity
%% for everything hecate_om does, because it is a fleet service; only its output
%% moves.
%%
%%     net.beamcampus.dronex
%%     686fbbf84c5c33455764f4c07c642bd1b79ef4efc78455f61ac12936ca3bffe3
%%
%% It costs nothing to draw this line: macula is realm-per-call, so one pool
%% publishes to any realm and this is a second realm rather than a second
%% connection, and a realm id is the sha256 of its name, so a public realm needs
%% no provisioning and its name being public is the point.
%%
%% ⚠ THE INBOUND DIRECTION IS DELIBERATELY NOT HERE YET. CHARTER.md puts a raid
%% REQUEST on the FLEET realm, because running a stranger's swarm costs a shared
%% four-core box real CPU and is therefore gated, while facts go out on the
%% public one. That asymmetry arrives with the raid protocol at order-of-work
%% item 7, in the same commit as the code that answers a request. A door opened
%% before there is anything behind it is a door.
%%
%% HONEST LIMIT: stations are realm-agnostic infrastructure, so a realm is a
%% routing namespace and not an enforced permission. What this buys is that a
%% public web box never holds the fleet tag, not that the fleet tag would be
%% refused if it did.
-module(dronex_mesh).

%% Longer than an engagement can take. `max_ticks' is 1200 at 20 Hz, and the
%% defender validates a whole sortie before it starts.
-define(RAID_TIMEOUT_MS, 120000).

-export([publish/2, available/0, publish_realm/1, station/0]).
-export([advertise/2, call/2, subscribe/2]).
-export([publish_between_islands/2, subscribe_between_islands/2]).

%% ==========================================================================
%% ⚠ WHICH REALM A TOPIC LIVES ON IS DECIDED BY WHO IT IS FOR
%% ==========================================================================
%%
%% PUBLIC — what a spectator watches. `vitals', `bout' and the raid RECORDING.
%% Anyone may read them; the realm tag is the sha256 of its own name, so it is
%% derived rather than issued and a stranger needs nothing from us.
%%
%% FLEET — what islands say TO EACH OTHER. Availability and settlement. A
%% stranger can therefore watch every fight in the archipelago and can neither
%% join the conversation nor start one, which is the access control the whole
%% design rests on.
%%
%% ⚠⚠ SETTLEMENT IS NOT THE RECORDING, AND THE SIZE IS WHY. A raid fact carries
%% frames — of the order of 150 KB. An island needs the FATES of six genomes to
%% put its survivors back, which is a few hundred bytes. Settling off the public
%% recording would make every island in the archipelago download every fight to
%% learn the outcome of its own, which is exactly the waste that subscribing to
%% `vitals' for presence was.

%% ==========================================================================
%% ⚠ TWO DIRECTIONS, TWO REALMS, AND THE ASYMMETRY IS THE ACCESS CONTROL
%% ==========================================================================
%%
%% FACTS GO OUT on the public realm, which is the sha256 of its own name and so
%% is derived rather than issued: anybody may read an island, and a public web
%% container never holds the fleet tag that routes sentinel sightings.
%%
%% RAIDS GO BOTH WAYS on the FLEET realm. That is the whole access control: a
%% stranger watching the exhibit can see every fight and cannot start one,
%% because starting one means calling a procedure on a realm they do not have.
%%
%% HEARING OTHER ISLANDS happens on the PUBLIC realm, because that is where
%% islands become visible to each other. There is no directory and no registry;
%% an island learns that another exists by watching it publish, which is why an
%% island that is silent is never attacked. That is a consequence of the design
%% rather than a protection anybody added.

%% @doc Offer this island's raid procedure to the fleet.
-spec advertise(binary(), fun((term()) -> term())) -> ok | {error, term()}.
advertise(Procedure, Handler) when is_binary(Procedure), is_function(Handler, 1) ->
    offered(Procedure, Handler, endpoint(), fleet_realm()).

offered(_P, _H, {error, _} = E, _Realm) -> E;
offered(_P, _H, _Pool, {error, _} = E) -> E;
offered(Procedure, Handler, {ok, Pool}, {ok, Realm}) ->
    try macula:advertise(Pool, Realm, Procedure, Handler, #{})
    catch Class:Reason -> {error, {advertise_failed, Class, Reason}}
    end.

%% @doc Call another island's raid procedure.
%%
%% ⚠ A LONG TIMEOUT, BECAUSE THE CALLEE IS FIGHTING. The defender validates every
%% genome, then runs a whole engagement of up to 1200 ticks before it can answer.
%% A five-second default would report `timeout' for a raid that is going
%% perfectly, and the attacker would count its party lost while the defender
%% counted it beaten.
%% ⚠ NO SEPARATE ISLAND ARGUMENT. The first version took one, validated it in a
%% guard and never read it: `dronex_raid:procedure/1' already encodes the target,
%% so the island was a second copy of the address that nothing compared against
%% the first. A guard counts as a use, so the compiler said nothing — which is
%% REGISTER I.7 exactly, where `breed:random/2' carried a parameter every caller
%% passed zero to and dialyzer's warnings were about anything but the defect.
-spec call(binary(), term()) -> {ok, term()} | {error, term()}.
call(Procedure, Payload) when is_binary(Procedure) ->
    dialled(Procedure, Payload, endpoint(), fleet_realm()).

dialled(_P, _Payload, {error, _} = E, _Realm) -> E;
dialled(_P, _Payload, _Pool, {error, _} = E) -> E;
dialled(Procedure, Payload, {ok, Pool}, {ok, Realm}) ->
    try macula:call(Pool, Realm, Procedure, Payload, ?RAID_TIMEOUT_MS)
    catch Class:Reason -> {error, {call_failed, Class, Reason}}
    end.

%% @doc Watch a topic on the PUBLIC realm. The subscriber receives
%% `{macula_event, SubRef, Topic, Payload, Meta}'.
%%
%% ⚠ FIVE ELEMENTS, AND A SIBLING'S FOUR-ELEMENT CLAUSE DROPPED EVERY FACT IT
%% EVER RECEIVED. Nothing raised, nothing logged, the subscription was live and
%% the publisher's counter read hundreds sent. Whoever matches on this shape must
%% match all five.
-spec subscribe(binary(), pid()) -> {ok, reference()} | {error, term()}.
subscribe(Topic, Subscriber) when is_binary(Topic), is_pid(Subscriber) ->
    watched(Topic, Subscriber, endpoint(), publish_realm_or_fleet()).

watched(_T, _S, {error, _} = E, _Realm) -> E;
watched(_T, _S, _Pool, {error, _} = E) -> E;
watched(Topic, Subscriber, {ok, Pool}, {ok, Realm}) ->
    try macula_client:subscribe(Pool, Realm, Topic, Subscriber, #{})
    catch Class:Reason -> {error, {subscribe_failed, Class, Reason}}
    end.

%% The realm facts go out on, which is also the realm they come in on: an island
%% hears its neighbours exactly where a spectator hears all of them.
publish_realm_or_fleet() -> realm_for(os:getenv("HECATE_DRONEX_REALM")).

-spec publish(binary(), map()) -> ok | {error, term()}.
publish(Topic, Fact) when is_map(Fact) ->
    send(Topic, Fact, endpoint(), realm_for(os:getenv("HECATE_DRONEX_REALM"))).

%% @doc Publish where only other islands are listening.
-spec publish_between_islands(binary(), map()) -> ok | {error, term()}.
publish_between_islands(Topic, Fact) when is_map(Fact) ->
    send(Topic, Fact, endpoint(), fleet_realm()).

%% @doc Watch a topic only islands speak on.
-spec subscribe_between_islands(binary(), pid()) -> {ok, reference()} | {error, term()}.
subscribe_between_islands(Topic, Subscriber) when is_binary(Topic), is_pid(Subscriber) ->
    watched(Topic, Subscriber, endpoint(), fleet_realm()).

%% @doc WHICH DOOR THIS ISLAND REACHES THE MESH THROUGH, read from the live
%% connection rather than from configuration.
%%
%% THE SEED IS NOT THE STATION. `host' is the name this island DIALLED, which is
%% configuration echoed back and can be a DNS name over any box; `node_id' is the
%% station's Ed25519 public key, verified during the signed HELLO, and is the
%% only trustworthy answer to which station actually answered. Both go out,
%% because they are different claims and a reader is entitled to see them
%% disagree.
%%
%% A NAME IS NOT A PLACE. `station-de-frankfurt' was for a long time physically
%% the Nuremberg box, left misnamed because renaming breaks seeds, and it has
%% since moved again. Stations are virtual and there are hundreds of names over a
%% handful of machines, so nothing downstream may render a city from this.
%%
%% INSULATED LIKE `publish/2'. The mesh is an output and not a dependency, so a
%% door that cannot be read is an error a caller shrugs at rather than something
%% that takes the island down.
-spec station() -> {ok, map()} | {error, term()}.
station() -> door(endpoint()).

door({error, _} = E) -> E;
door({ok, Pool}) ->
    try chosen(macula:links(Pool))
    catch Class:Reason -> {error, {links_failed, Class, Reason}}
    end.

chosen({error, _} = E) -> E;
chosen({ok, []}) -> {error, no_links};
chosen({ok, Links}) -> {ok, described(prefer_connected(Links))}.

%% An island dials one seed, so there is normally one link. If a deployment ever
%% gives it several, the one that is actually up is the one it is speaking
%% through, and a down link is still worth reporting when nothing is up.
prefer_connected(Links) ->
    hd([L || L <- Links, maps:get(connected, L, false) =:= true] ++ Links).

described(#{host := Host, connected := Connected} = Link) ->
    #{station_host => host_or_unknown(Host),
      station_connected => Connected,
      station_id => key(maps:get(node_id, Link, undefined))}.

host_or_unknown(Host) when is_binary(Host) -> Host;
host_or_unknown(_) -> <<"unknown">>.

%% Lowercase hex, whole. A reader that wants a short form can take a prefix; one
%% that wants to verify the key against the mesh needs all of it.
key(Key) when is_binary(Key) -> string:lowercase(binary:encode_hex(Key));
key(_) -> <<>>.

send(_Topic, _Fact, {error, _} = E, _Realm) -> E;
send(Topic, Fact, {ok, Pool}, Realm) -> send_on(Topic, Fact, Pool, Realm).

%% ==========================================================================
%% A STRANGER NEEDS NO SECRET, AND A SIBLING'S CODE DEMANDED ONE IT NEVER USED
%% ==========================================================================
%%
%% There, `endpoint/0' required a pool AND the fleet realm, and then the next
%% function threw the fleet realm away and published on the public realm instead.
%% So an island run by somebody outside the fleet, with the public realm set and
%% no fleet tag to its name, could not publish at all: it failed a check on a
%% value the next line discards.
%%
%% ⚠ AND THAT MATTERS MORE HERE THAN IT DID THERE. CHARTER.md's archipelago is
%% real machines belonging to different owners, and its one idea is that a raid
%% carries genomes between populations that were bred independently. A substrate
%% that quietly requires fleet membership to speak would make every island ours,
%% and the diversity being pumped across the mesh would come from one breeder.
realm_for(false) -> fleet_realm();
realm_for("") -> fleet_realm();
realm_for(Hex) -> from_hex(Hex, undefined).

fleet_realm() ->
    try hecate_om_identity:realm()
    catch Class:Reason -> {error, {no_realm, Class, Reason}}
    end.

send_on(_Topic, _Fact, _Pool, {error, _} = E) -> E;
send_on(Topic, Fact, Pool, {ok, Realm}) ->
    try macula:publish(Pool, Realm, Topic, Fact)
    catch Class:Reason -> {error, {publish_failed, Class, Reason}}
    end.

%% @doc Which realm facts go out on, given the fleet realm to fall back to.
%%
%% Unset falls back, so a deployment that has not been told about the public
%% realm keeps behaving as it did rather than going silent.
%%
%% A MALFORMED TAG IS AN ERROR RATHER THAN A FALLBACK. Falling back on a typo
%% would publish public facts onto the operational realm and report success,
%% which is the one outcome nobody would notice.
-spec publish_realm(binary()) -> {ok, binary()} | {error, term()}.
publish_realm(FleetRealm) -> from_hex(os:getenv("HECATE_DRONEX_REALM"), FleetRealm).

from_hex(false, FleetRealm) -> {ok, FleetRealm};
from_hex("", FleetRealm) -> {ok, FleetRealm};
from_hex(Hex, FleetRealm) -> decode(string:trim(Hex), FleetRealm).

decode(Hex, _FleetRealm) when length(Hex) =:= 64 ->
    try {ok, binary:decode_hex(list_to_binary(Hex))}
    catch _:_ -> {error, dronex_realm_not_hex}
    end;
decode(_Hex, _FleetRealm) -> {error, dronex_realm_not_64_hex}.

-spec available() -> boolean().
available() -> element(1, endpoint()) =:= ok.

%% The pool and the realm both come from hecate_om, which owns the connection and
%% the identity. This service holds neither.
%%
%% WRAPPED, AND THE DEVIATION IS DELIBERATE. Both of those are gen_server calls,
%% so before hecate_om is up, or while it is restarting, they do not return an
%% error: they EXIT with noproc. Unwrapped, that exit travels up through the
%% publish timer and kills the island, which restarts and loses the roster it was
%% holding. An island must outlive its transport, so the failure becomes a return
%% value the caller can count.
%%
%% What would be lost without this is precisely the distinction between "the mesh
%% is not there yet" and "the island crashed", which a supervisor exit collapses
%% into one opaque line.
endpoint() ->
    try pool(hecate_om_identity:macula_client())
    catch Class:Reason -> {error, {no_hecate_om, Class, Reason}}
    end.

pool({ok, Pool}) -> {ok, Pool};
pool(Other) -> {error, {no_macula_client, Other}}.
