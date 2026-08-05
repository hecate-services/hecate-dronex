%% @doc The island's static defence: what it sees, what it says, and the
%% asymmetry that prices a raid.
-module(ground_network_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

-define(M, 20480).

%% A drone standing on the centre sensor, so it is certainly in earshot.
at_the_centre(Side) ->
    #{arena_x := Ax, arena_y := Ay} = airspace:limits(),
    #drone{id = probe, side = Side, x = Ax div 2, y = Ay div 2, z = 100 * ?M,
           signal = [0, 0, 0, 0]}.

%% Fly a drone past the middle of the arena for N ticks, letting the network look
%% at it each tick.
watched(Net, Drone, Ticks) ->
    lists:foldl(fun (T, N) -> ground_network:observe(N, [Drone], T) end, Net,
                lists:seq(1, Ticks)).

loud(Net, D) -> ground_network:transmission(Net, D) =/= [0, 0, 0, 0].

%%==============================================================================
%% ⚠ AWAY MEANS NO GROUND AT ALL
%%==============================================================================

no_network_sees_nothing_and_says_nothing_test() ->
    N = ground_network:none(),
    ?assertEqual([], ground_network:sensors(N)),
    ?assertEqual([], ground_network:tracks_of(N)),
    ?assertEqual(N, ground_network:observe(N, [at_the_centre(attacker)], 5)),
    %% An attacker in somebody else's volume has no ground support whatever.
    %% This is the second price of raiding, on top of spending airframes.
    ?assertEqual([0, 0, 0, 0], ground_network:transmission(N, at_the_centre(attacker))).

a_home_network_has_stations_test() ->
    ?assertEqual(?SENSORS, length(ground_network:sensors(ground_network:home()))),
    ?assertEqual(3, length(ground_network:sensors(ground_network:home(3)))).

the_count_comes_from_the_physics_test() ->
    %% Not a private constant in this module. A second copy on one release
    %% cadence is CHARTER rule 2's failure in miniature, and it would also fall
    %% out of the engine fingerprint.
    #{sensors := N} = airspace:limits(),
    ?assertEqual(length(ground_network:sensors(ground_network:home(N))),
                 length(ground_network:sensors(ground_network:home()))).

%%==============================================================================
%% ⚠⚠ SILENT UNTIL CONFIRMED
%%==============================================================================

a_fresh_network_says_nothing_test() ->
    %% It has stations and no picture. A network that transmitted its tentative
    %% picture would broadcast its ghosts, and the confirmation threshold — the
    %% number this phase exists to tune — would decide nothing.
    ?assertNot(loud(ground_network:home(), at_the_centre(defender))).

%% ⚠ A FRESH NETWORK HAS NO TRACKS AT ALL, so the test above passes whether the
%% threshold is respected or ignored — a guard probe that replaced
%% `ground_tracks:confirmed(T)' with `T' left it green. This one puts a TENTATIVE track
%% in the picture and nothing else, which is the only state that tells the two
%% apart.
%%
%% ⚠⚠ ONE STATION, DELIBERATELY. A five-station network confirms a target in the
%% middle of it almost at once, because every station reports the same place in
%% the same tick and the threshold is met before a second tick happens. That is
%% correct and is asserted below; it also means the full network never sits in
%% the tentative state long enough to test it.
a_network_with_only_a_tentative_track_says_nothing_test() ->
    D = at_the_centre(attacker),
    Seen = seen_for(ground_network:home(1), D, ?CONFIRM_EVIDENCE - 1),
    ?assert(seen_something(Seen)),
    ?assertEqual([], ground_network:tracks_of(Seen)),
    ?assertNot(loud(Seen, at_the_centre(defender))).

%% ⚠ WHAT A NETWORK IS ACTUALLY FOR, and it falls out of the design rather than
%% being arranged. Several stations reporting the same place in the same tick
%% clears the threshold immediately, while several stations' GHOSTS do not,
%% because each station invents its own at its own position and they do not
%% coincide inside the gate. Agreement is the evidence.
several_stations_agreeing_confirm_faster_than_one_test() ->
    D = at_the_centre(attacker),
    ?assert(ticks_to_confirm(ground_network:home(), D) < ticks_to_confirm(ground_network:home(1), D)).

ticks_to_confirm(Net, Drone) -> ticks_to_confirm(Net, Drone, 1).

ticks_to_confirm(_Net, _Drone, T) when T > 300 -> never;
ticks_to_confirm(Net, Drone, T) ->
    Next = ground_network:observe(Net, [Drone], T),
    reached(ground_network:tracks_of(Next), Next, Drone, T).

reached([], Net, Drone, T) -> ticks_to_confirm(Net, Drone, T + 1);
reached(_Confirmed, _Net, _Drone, T) -> T.

%% Look until the tracker holds N pieces of evidence on something. Detection is
%% probabilistic, so counting ticks would count misses too.
seen_for(Net, Drone, Evidence) ->
    lists:foldl(fun (T, N) -> maybe_look(N, Drone, T, Evidence) end, Net,
                lists:seq(1, 400)).

maybe_look(Net, Drone, Tick, Evidence) ->
    stopped(evidence_in(Net) >= Evidence, Net, Drone, Tick).

stopped(true, Net, _Drone, _Tick) -> Net;
stopped(false, Net, Drone, Tick) -> ground_network:observe(Net, [Drone], Tick).

evidence_in(#{tracks := Ts}) -> lists:max([0 | [E || #{evidence := E} <- Ts]]).

seen_something(#{tracks := Ts}) -> Ts =/= [].

after_watching_something_for_long_enough_it_speaks_test() ->
    D = at_the_centre(attacker),
    Net = watched(ground_network:home(), D, 60),
    ?assert(ground_network:tracks_of(Net) =/= []),
    ?assert(loud(Net, at_the_centre(defender))).

what_it_says_is_four_integers_like_any_other_transmission_test() ->
    Net = watched(ground_network:home(), at_the_centre(attacker), 60),
    Said = ground_network:transmission(Net, at_the_centre(defender)),
    ?assertEqual(4, length(Said)),
    #{signal_max := Max} = airspace:limits(),
    %% ⚠ NOT A NEW SENSOR CHANNEL. Extra channels for defenders would mean two
    %% input widths, two genome shapes, two rosters, and two populations that
    %% cannot be drawn from one pool — which would end the single-population
    %% property that makes a captured genome usable by its captor.
    [?assert(V >= -Max andalso V =< Max) || V <- Said],
    ?assertEqual(drone_senses:comms_width() div radio:banks(), length(Said)).

%%==============================================================================
%% ⚠ IT WATCHES EVERYONE, INCLUDING ITS OWN SIDE
%%==============================================================================

the_network_tracks_the_defenders_too_test() ->
    %% A non-cooperative sensor does not learn whose aircraft it is looking at.
    %% Filtering by side would hand a defending controller an answer no real
    %% sensor could give it, which is why Remote-ID was the wrong first modality.
    Net = watched(ground_network:home(), at_the_centre(defender), 60),
    ?assert(ground_network:tracks_of(Net) =/= []).

%%==============================================================================
%% ⚠ THE ATTACKER HEARS IT TOO
%%==============================================================================

a_network_that_talks_reveals_that_it_has_seen_you_test() ->
    Net = watched(ground_network:home(), at_the_centre(attacker), 60),
    Heard = ground_network:transmission(Net, at_the_centre(attacker)),
    %% Going loud is a decision rather than a default, and an attacker can learn
    %% WHEN IT HAS BEEN SEEN — a real capability nobody had to design in.
    ?assertEqual(ground_network:transmission(Net, at_the_centre(defender)), Heard),
    ?assertNotEqual([0, 0, 0, 0], Heard).

%%==============================================================================
%% ⚠ THE GROUND IS RANGE-LIMITED LIKE ANY OTHER TRANSMITTER
%%==============================================================================

a_drone_out_of_comms_range_hears_nothing_test() ->
    #{arena_x := Ax, arena_y := Ay, arena_z := Az} = airspace:limits(),
    Net = watched(ground_network:home(), at_the_centre(attacker), 60),
    Corner = #drone{id = far, side = attacker, x = Ax - 1, y = Ay - 1, z = Az - 1,
                    signal = [0, 0, 0, 0]},
    %% Flying wide is a way to stop being cued at and, for an attacker, a way to
    %% stop hearing that it has been seen. Both are approach-path decisions,
    %% which is the counterplay this design wants a controller to be able to
    %% discover.
    ?assertNot(loud(Net, Corner)).

%%==============================================================================
%% Determinism
%%==============================================================================

two_islands_looking_at_the_same_fight_see_the_same_thing_test() ->
    D = at_the_centre(attacker),
    ?assertEqual(watched(ground_network:home(), D, 40), watched(ground_network:home(), D, 40)).

%%==============================================================================
%% ⚠⚠⚠ THE WIRING. WITHOUT THESE THE MODULE COMPILES AND DEFENDS NOTHING
%%==============================================================================

%% ⚠ THIS IS THE ONE THAT MATTERS. Item 8 was built, compiled, tested and wired
%% into nothing for a while: `ground_network:home/1' was called from no production
%% module, so every fight ran with `none' and the whole static defence was dead
%% code with green tests behind it. A test that only exercises the modules
%% directly cannot see that, because it supplies the network itself.
the_ground_reaches_the_result_test() ->
    {ok, C} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, 0),
    [{A, _, _, _, _, _}, {B, _, _, _, _, _}] = Placed,
    Home = engagement:run(airspace:new(Placed), #{A => C, B => C},
                          #{network => ground_network:home()}),
    Away = engagement:run(airspace:new(Placed), #{A => C, B => C},
                          #{network => ground_network:none()}),
    ?assertEqual(?SENSORS, length(maps:get(ground, Home))),
    %% Empty is the honest answer for an away game, and it is what lets a
    %% spectator see that a raider fought without towers.
    ?assertEqual([], maps:get(ground, Away)),
    [?assertEqual([x, y, z], lists:sort(maps:keys(S))) || S <- maps:get(ground, Home)].

a_network_actually_changes_what_a_swarm_hears_test() ->
    %% If the cue never reached a controller's input, everything above would pass
    %% and the ground bank would still be twelve zeroes for ever.
    D = at_the_centre(defender),
    Net = watched(ground_network:home(), at_the_centre(attacker), 60),
    Cued = radio:heard(D, [], none, ground_network:transmission(Net, D)),
    ?assertNotEqual(radio:silence(), Cued),
    ?assertEqual(radio:width(), length(Cued)),
    %% And it lands in the GROUND bank, not in one of the air banks.
    {Air, Ground} = lists:split(8, Cued),
    ?assertEqual(lists:duplicate(8, 0), Air),
    ?assertNotEqual([0, 0, 0, 0], Ground).

the_benchmark_is_an_away_game_test() ->
    %% ⚠ NOT OPTIONAL AND EASY TO MISS. The frozen ladder measures the
    %% CONTROLLER. A network here would score an island's terrain instead, every
    %% rung would move the day placement changed, and the one fixed thing in the
    %% system would stop being fixed.
    Bin = source(benchmark),
    ?assert(binary:match(Bin, <<"ground_network:none()">>) =/= nomatch),
    ?assertEqual(nomatch, binary:match(Bin, <<"ground_network:home">>)).

training_happens_under_the_islands_own_network_test() ->
    %% Selection cannot favour using a cue that is never present. Without this
    %% the ground bank would be four zeroes for every generation that ever ran,
    %% and the ablation's ground arm would read zero honestly and uselessly.
    ?assert(binary:match(source(trainer), <<"ground_network:home()">>) =/= nomatch).

%% ⚠ CALLED, NOT GREPPED. This assertion used to read `island_server.erl' for the
%% string `ground_network:home()' and passed while the raid path was perturbed to
%% `none', because the same string also appears on the training-bout path a few
%% hundred lines away. A textual probe cannot tell two occurrences apart, which
%% is half the reason hosting moved into `defence' — the other half is that how a
%% raid is defended is a fact about defending.
a_hosted_raid_is_fought_at_home_test() ->
    {ok, C} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, 0),
    [{A, _, _, _, _, _}, {B, _, _, _, _, _}] = Placed,
    Result = (defence:host(#{A => C, B => C}))(airspace:new(Placed)),
    ?assertEqual(?SENSORS, length(maps:get(ground, Result))),
    %% And it records, because a raid nobody can watch is not an exhibit.
    ?assert(maps:get(frames, Result) =/= false).

%% ⚠ THE PATH COMES FROM THE COMPILER, NOT FROM A GUESS AT THE WORKING DIRECTORY.
%% A relative climb out of `_build' is a probe that rots the day anything moves,
%% and a probe that cannot find its file must fail loudly rather than quietly
%% pass — REGISTER I.10 was exactly this shape.
source(Module) ->
    Path = proplists:get_value(source, Module:module_info(compile)),
    ?assert(Path =/= undefined),
    {ok, Bin} = file:read_file(Path),
    Bin.

the_towers_reach_the_wire_test() ->
    %% A spectator cannot draw what was never published. Both a bout and a raid
    %% go through one encoder, so this covers both.
    {ok, C} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, 0),
    [{A, _, _, _, _, _}, {B, _, _, _, _, _}] = Placed,
    Run = fun (Net) ->
              engagement:run(airspace:new(Placed), #{A => C, B => C},
                             #{frames => true, network => Net})
          end,
    Enc = fun (R) -> dronex_bout:encode(#{}, R, maps:get(frames, R), airspace:limits()) end,
    Home = Enc(Run(ground_network:home())),
    ?assertEqual([x, y, z], maps:get(ground_fields, Home)),
    ?assertEqual(?SENSORS * 3, length(maps:get(ground, Home))),
    %% Metres, like the arena and the frames, so a reader never mixes units.
    #{arena_x := Ax} = airspace:limits(),
    [?assert(V >= 0 andalso V =< Ax div 20480) || V <- maps:get(ground, Home)],
    ?assertEqual([], maps:get(ground, Enc(Run(ground_network:none())))),
    %% The reach travels too, because five dots without it is a picture of the
    %% towers rather than a picture of the defence.
    #{sensor_range := R} = airspace:limits(),
    ?assertEqual(R div 20480, maps:get(ground_range, Home)).

%% ⚠ WHAT THE GROUND CONFIRMED MUST REACH THE WIRE, AND IT IS NOT THE SAME LIST
%% AS THE DRONES. A scoreline cannot tell "the raiders got through" from "the
%% raiders were never confirmed", and those are different findings about the same
%% defeat — one says the swarm out-flew the network, the other says the network
%% never spoke.
the_confirmed_picture_reaches_the_wire_test() ->
    {ok, C} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, 0),
    [{A, _, _, _, _, _}, {B, _, _, _, _, _}] = Placed,
    Run = fun (Net) ->
              engagement:run(airspace:new(Placed), #{A => C, B => C},
                             #{frames => true, network => Net})
          end,
    Home = Run(ground_network:home()),
    Enc = dronex_bout:encode(#{}, Home, maps:get(frames, Home), airspace:limits()),
    ?assertEqual([x, y, z], maps:get(track_fields, Enc)),
    Ks = [maps:get(k, F) || F <- maps:get(frames, Enc)],
    ?assert(lists:any(fun (K) -> K =/= [] end, Ks)),
    [?assertEqual(0, length(K) rem 3) || K <- Ks],

    %% ⚠ AND IT DOES NOT START EMPTY, WHICH IS A FINDING RATHER THAN A BUG.
    %% This assertion was written the other way round on the assumption that a
    %% recording would open with a silent network and show it go loud. It never
    %% does: the drones start where several domes overlap, so tracks are
    %% confirmed on the first frame. See REGISTER D.13 — the going-loud mechanic
    %% does not engage at these settings, and the sweep has to move the geometry
    %% and not only the station count.
    ?assert(hd(Ks) =/= []),

    %% Metres, like every other position on the wire.
    #{arena_x := Ax} = airspace:limits(),
    [?assert(V > -Ax div 20480 andalso V < 2 * (Ax div 20480))
     || K <- Ks, V <- K],

    %% An away fight confirms nothing, because it has no network to confirm with.
    Away = Run(ground_network:none()),
    AwayEnc = dronex_bout:encode(#{}, Away, maps:get(frames, Away), airspace:limits()),
    ?assertEqual([], lists:append([maps:get(k, F) || F <- maps:get(frames, AwayEnc)])).

%% ⚠ THE BELIEF IS NOT THE TRUTH, and a frame that merged them would erase the
%% only thing this subsystem models. A track lags the drone it is about, and it
%% is anonymous: nothing in the row says which aircraft it is, because a
%% non-cooperative sensor never learns that.
a_track_is_not_a_drone_test() ->
    {ok, C} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, 0),
    [{A, _, _, _, _, _}, {B, _, _, _, _, _}] = Placed,
    R = engagement:run(airspace:new(Placed), #{A => C, B => C},
                       #{frames => true, network => ground_network:home()}),
    Enc = dronex_bout:encode(#{}, R, maps:get(frames, R), airspace:limits()),
    Late = lists:last(maps:get(frames, Enc)),
    %% Three numbers per track against seven per drone: no id, no yaw, no health,
    %% no state. There is nothing in a track to pair it with an aircraft.
    ?assertEqual(3, length(maps:get(track_fields, Enc))),
    ?assertEqual(7, dronex_bout:stride()),
    ?assert(maps:get(k, Late) =/= []),

    %% ⚠ AND THE COUNTS MUST DISAGREE SOMEWHERE. If the network's picture always
    %% held exactly one track per live drone it would be ground truth wearing a
    %% different field name, and every missed detection, every ghost and the
    %% whole confirmation threshold would be decorative.
    Frames = maps:get(frames, Enc),
    Pairs = [{length(maps:get(k, F)) div 3, length(maps:get(d, F)) div 7} || F <- Frames],
    ?assert(lists:any(fun ({T, D}) -> T =/= D end, Pairs)).
