%% @doc An island's static defence: what it sees, and what it says about it.
%%
%% THIS EXISTS SO THAT TWO ISLANDS ARE DIFFERENT PLACES RATHER THAN GENERIC BOXES
%% WITH DIFFERENT GENOMES IN THEM.
%%
%% ==========================================================================
%% ⚠ YOU FIGHT AT HOME WITH YOUR NETWORK, AND AWAY WITHOUT IT
%% ==========================================================================
%%
%% An island's sensors defend its own airspace. When it raids, its drones fly
%% into somebody else's volume with no ground support at all. That prices a raid
%% a second time on top of spending airframes: attacking is genuinely harder than
%% defending, and choosing to attack means giving up the thing that makes you
%% strong.
%%
%% ⚠⚠ IT IS ALSO THE DESIGN'S MOST LIKELY FAILURE MODE, so the criterion is
%% written down before the dial is set: **a competent attacking swarm must win a
%% non-trivial fraction of raids against a competent defence.** If home advantage
%% is overwhelming every island turtles, nothing raids, no genomes cross, and the
%% charter's one idea dies quietly while the exhibit still looks busy. Sensor
%% count and range are chosen on that measurement with the whole sweep published,
%% including the settings that made attacking hopeless. Charter rule 3.
%%
%% ==========================================================================
%% ⚠⚠⚠ THE NETWORK TRANSMITS. IT DOES NOT GET A PRIVILEGED INPUT
%% ==========================================================================
%%
%% The obvious way to give a defender its ground picture is new sensor channels —
%% a `cued_contact_bearing' and so on. That is structurally wrong. Extra channels
%% for defenders means attackers and defenders have different input widths, which
%% means two genome shapes, two rosters, and two populations that cannot be drawn
%% from one pool. The single-population property is what makes a sortie a draw
%% from the roster rather than an assembly of declared roles, and it is what makes
%% a captured genome usable by its captor.
%%
%% So the network has a voice on the same uninterpreted comms channel the drones
%% have, and four things fall out for free:
%%
%%   a defending drone must LEARN to use the cue, because it arrives as four
%%   integers whose meaning nothing declares, exactly like every other transmission
%%
%%   the attacker hears it, so a network that talks reveals that it has detected
%%   you, and going loud is a decision rather than a default
%%
%%   an attacker can learn to listen, which is to say learn WHEN IT HAS BEEN SEEN,
%%   a real capability nobody had to design
%%
%%   one genome shape survives
-module(network).

-include("airspace.hrl").

-export([none/0, home/0, home/1, observe/3, transmission/2, sensors/1, tracks_of/1]).

-export_type([network/0]).

-type network() :: none | #{sensors := [sensor:sensor()], tracks := tracks:state()}.

%% @doc No network at all, which is what an attacker has in somebody else's
%% airspace and what the frozen benchmark always runs with.
-spec none() -> network().
none() -> none.

%% @doc The island's own network, as it stands at the start of an engagement.
%%
%% The count is physics and comes from `airspace:limits/0', so it is inside the
%% engine fingerprint: two islands with different networks refuse each other
%% rather than fighting a match neither can interpret.
-spec home() -> network().
home() ->
    #{sensors := N} = airspace:limits(),
    home(N).

-spec home(pos_integer()) -> network().
home(N) -> #{sensors => sensor:place(N), tracks => tracks:empty()}.

-spec sensors(network()) -> [sensor:sensor()].
sensors(none) -> [];
sensors(#{sensors := S}) -> S.

-spec tracks_of(network()) -> [tracks:track()].
tracks_of(none) -> [];
tracks_of(#{tracks := T}) -> tracks:confirmed(T).

%%==============================================================================
%% One tick of looking
%%==============================================================================

%% @doc Every sensor observes every drone, and the contacts become tracks.
%%
%% ⚠ IT WATCHES EVERYONE, INCLUDING THE DEFENDER'S OWN DRONES. A non-cooperative
%% sensor does not know whose aircraft it is looking at — that is what
%% non-cooperative MEANS, and it is why Remote-ID is the wrong first modality
%% here rather than the obvious one. So the network's picture contains its own
%% side too, and a defending controller has to work out which cues are worth
%% acting on. Filtering by side would be handing it an answer no real sensor
%% could give it.
-spec observe(network(), [#drone{}], non_neg_integer()) -> network().
observe(none, _Drones, _Tick) ->
    none;
observe(#{sensors := Sensors, tracks := Tracks}, Drones, Tick) ->
    Contacts = seen(Sensors, [D || D <- Drones, not D#drone.dead], Tick)
               ++ sensor:ghosts(Sensors, Tick),
    #{sensors => Sensors, tracks => tracks:advance(Tracks, Contacts, Tick)}.

seen(Sensors, Drones, Tick) ->
    [C || S <- Sensors, D <- Drones,
          {ok, C} <- [sensor:observe(truth(D), S, #{tick => Tick})]].

%% The sensor behaviour takes ground truth as a map, because that is the shape a
%% real sensor's driver would be handed. The drone record is the truth.
truth(#drone{id = Id, x = X, y = Y, z = Z}) -> #{id => Id, x => X, y => Y, z => Z}.

%%==============================================================================
%% What the ground says
%%==============================================================================

%% @doc The four integers a drone at this position hears from the ground.
%%
%% ⚠ UNINTERPRETED, LIKE EVERY OTHER TRANSMISSION. Nothing declares what these
%% mean. They are the network's confirmed picture, scaled onto the channel's
%% range, and a controller that wants to use them has to learn what they are —
%% which is the same bargain the drones' own comms channel strikes, and charter
%% rule 8 at its sharpest: naming a channel would be naming a tactic nobody
%% evolved.
%%
%% ⚠⚠ AND IT IS SILENT UNTIL A TRACK IS CONFIRMED. A network that transmitted its
%% tentative picture would be broadcasting its ghosts, and the confirmation
%% threshold — the interesting number — would decide nothing.
-spec transmission(network(), #drone{}) -> [integer()].
transmission(none, _Drone) ->
    silence();
transmission(#{sensors := Sensors, tracks := Tracks}, #drone{} = D) ->
    heard_from(in_earshot(Sensors, D), tracks:confirmed(Tracks)).

silence() -> [0, 0, 0, 0].

%% ⚠ THE GROUND IS RANGE-LIMITED LIKE ANY OTHER TRANSMITTER. A drone hears the
%% network only while it is near one of its stations, so flying wide is a way to
%% stop being cued at — and, for an attacker, a way to stop hearing that it has
%% been seen. Both are approach-path decisions, which is the counterplay this
%% design wants.
in_earshot(Sensors, #drone{x = X, y = Y, z = Z}) ->
    #{comms_range := R} = airspace:limits(),
    [S || #{x := Sx, y := Sy, z := Sz} = S <- Sensors,
          fixed:mag3(Sx - X, Sy - Y, Sz - Z) =< R].

heard_from([], _Confirmed) -> silence();
heard_from(_Sensors, []) -> silence();
heard_from(_Sensors, Confirmed) -> voice(Confirmed).

%% Where the network thinks the thing it is surest about is, and how much it is
%% seeing. Scaled onto the signal range so the ground bank and the air banks are
%% the same kind of number.
voice(Confirmed) ->
    #{signal_max := Max} = airspace:limits(),
    #{arena_x := Ax, arena_y := Ay, arena_z := Az} = airspace:limits(),
    #{x := X, y := Y, z := Z} = strongest(Confirmed),
    [scaled(X, Ax, Max), scaled(Y, Ay, Max), scaled(Z, Az, Max),
     %% How many confirmed tracks, saturating. A swarm arriving reads louder
     %% than a single drone, which is information a defender can act on without
     %% anybody deciding what it means.
     min(Max, length(Confirmed) * (Max div 8))].

%% The track with the most evidence behind it, so the cue is about the thing the
%% network is surest of rather than whichever happens to be first in a list.
strongest(Confirmed) ->
    hd(lists:sort(fun (#{evidence := A}, #{evidence := B}) -> A >= B end, Confirmed)).

%% Arena coordinates onto the signal's symmetric range.
scaled(V, Span, Max) -> fixed:clamp((V * 2 * Max) div Span - Max, -Max, Max).
