%% @doc The island's static defence: what it sees, what it says, and the
%% asymmetry that prices a raid.
-module(network_tests).

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
    lists:foldl(fun (T, N) -> network:observe(N, [Drone], T) end, Net,
                lists:seq(1, Ticks)).

loud(Net, D) -> network:transmission(Net, D) =/= [0, 0, 0, 0].

%%==============================================================================
%% ⚠ AWAY MEANS NO GROUND AT ALL
%%==============================================================================

no_network_sees_nothing_and_says_nothing_test() ->
    N = network:none(),
    ?assertEqual([], network:sensors(N)),
    ?assertEqual([], network:tracks_of(N)),
    ?assertEqual(N, network:observe(N, [at_the_centre(attacker)], 5)),
    %% An attacker in somebody else's volume has no ground support whatever.
    %% This is the second price of raiding, on top of spending airframes.
    ?assertEqual([0, 0, 0, 0], network:transmission(N, at_the_centre(attacker))).

a_home_network_has_stations_test() ->
    ?assertEqual(?SENSORS, length(network:sensors(network:home()))),
    ?assertEqual(3, length(network:sensors(network:home(3)))).

the_count_comes_from_the_physics_test() ->
    %% Not a private constant in this module. A second copy on one release
    %% cadence is CHARTER rule 2's failure in miniature, and it would also fall
    %% out of the engine fingerprint.
    #{sensors := N} = airspace:limits(),
    ?assertEqual(length(network:sensors(network:home(N))),
                 length(network:sensors(network:home()))).

%%==============================================================================
%% ⚠⚠ SILENT UNTIL CONFIRMED
%%==============================================================================

a_fresh_network_says_nothing_test() ->
    %% It has stations and no picture. A network that transmitted its tentative
    %% picture would broadcast its ghosts, and the confirmation threshold — the
    %% number this phase exists to tune — would decide nothing.
    ?assertNot(loud(network:home(), at_the_centre(defender))).

after_watching_something_for_long_enough_it_speaks_test() ->
    D = at_the_centre(attacker),
    Net = watched(network:home(), D, 60),
    ?assert(network:tracks_of(Net) =/= []),
    ?assert(loud(Net, at_the_centre(defender))).

what_it_says_is_four_integers_like_any_other_transmission_test() ->
    Net = watched(network:home(), at_the_centre(attacker), 60),
    Said = network:transmission(Net, at_the_centre(defender)),
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
    Net = watched(network:home(), at_the_centre(defender), 60),
    ?assert(network:tracks_of(Net) =/= []).

%%==============================================================================
%% ⚠ THE ATTACKER HEARS IT TOO
%%==============================================================================

a_network_that_talks_reveals_that_it_has_seen_you_test() ->
    Net = watched(network:home(), at_the_centre(attacker), 60),
    Heard = network:transmission(Net, at_the_centre(attacker)),
    %% Going loud is a decision rather than a default, and an attacker can learn
    %% WHEN IT HAS BEEN SEEN — a real capability nobody had to design in.
    ?assertEqual(network:transmission(Net, at_the_centre(defender)), Heard),
    ?assertNotEqual([0, 0, 0, 0], Heard).

%%==============================================================================
%% ⚠ THE GROUND IS RANGE-LIMITED LIKE ANY OTHER TRANSMITTER
%%==============================================================================

a_drone_out_of_comms_range_hears_nothing_test() ->
    #{arena_x := Ax, arena_y := Ay, arena_z := Az} = airspace:limits(),
    Net = watched(network:home(), at_the_centre(attacker), 60),
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
    ?assertEqual(watched(network:home(), D, 40), watched(network:home(), D, 40)).

%%==============================================================================
%% ⚠⚠⚠ THE WIRING. WITHOUT THESE THE MODULE COMPILES AND DEFENDS NOTHING
%%==============================================================================

%% ⚠ THIS IS THE ONE THAT MATTERS. Item 8 was built, compiled, tested and wired
%% into nothing for a while: `network:home/1' was called from no production
%% module, so every fight ran with `none' and the whole static defence was dead
%% code with green tests behind it. A test that only exercises the modules
%% directly cannot see that, because it supplies the network itself.
the_ground_reaches_the_result_test() ->
    {ok, C} = engagement:controller(hoverer),
    Placed = drone_starts:place(1, 1, 0),
    [{A, _, _, _, _, _}, {B, _, _, _, _, _}] = Placed,
    Home = engagement:run(airspace:new(Placed), #{A => C, B => C},
                          #{network => network:home()}),
    Away = engagement:run(airspace:new(Placed), #{A => C, B => C},
                          #{network => network:none()}),
    ?assertEqual(?SENSORS, length(maps:get(ground, Home))),
    %% Empty is the honest answer for an away game, and it is what lets a
    %% spectator see that a raider fought without towers.
    ?assertEqual([], maps:get(ground, Away)),
    [?assertEqual([x, y, z], lists:sort(maps:keys(S))) || S <- maps:get(ground, Home)].

a_network_actually_changes_what_a_swarm_hears_test() ->
    %% If the cue never reached a controller's input, everything above would pass
    %% and the ground bank would still be twelve zeroes for ever.
    D = at_the_centre(defender),
    Net = watched(network:home(), at_the_centre(attacker), 60),
    Cued = radio:heard(D, [], none, network:transmission(Net, D)),
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
    ?assert(binary:match(Bin, <<"network:none()">>) =/= nomatch),
    ?assertEqual(nomatch, binary:match(Bin, <<"network:home">>)).

training_happens_under_the_islands_own_network_test() ->
    %% Selection cannot favour using a cue that is never present. Without this
    %% the ground bank would be four zeroes for every generation that ever ran,
    %% and the ablation's ground arm would read zero honestly and uselessly.
    ?assert(binary:match(source(trainer), <<"network:home()">>) =/= nomatch).

a_hosted_raid_is_fought_at_home_test() ->
    ?assert(binary:match(source(island_server), <<"network:home()">>) =/= nomatch).

%% ⚠ THE PATH COMES FROM THE COMPILER, NOT FROM A GUESS AT THE WORKING DIRECTORY.
%% A relative climb out of `_build' is a probe that rots the day anything moves,
%% and a probe that cannot find its file must fail loudly rather than quietly
%% pass — REGISTER I.10 was exactly this shape.
source(Module) ->
    Path = proplists:get_value(source, Module:module_info(compile)),
    ?assert(Path =/= undefined),
    {ok, Bin} = file:read_file(Path),
    Bin.
