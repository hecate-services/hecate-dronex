%% @doc Hosting somebody else's raid.
-module(defence_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

roster_of(N, Seed) ->
    {R, _S} = trainer:seed_roster(roster:new(probe, 240), N, rand:seed_s(exsss, Seed)),
    R.

defenders(N) -> roster:entries(roster_of(N, {1, 2, 3})).

raiders(N) ->
    [{roster:entry_id(E), roster:entry_genome(E)} || E <- roster:entries(roster_of(N, {9, 8, 7}))].

%%==============================================================================
%% Composing
%%==============================================================================

both_sides_fly_and_the_pairing_comes_back_test() ->
    {ok, Arena, Controllers, Pairs} = defence:compose(defenders(3), raiders(3), 0),
    ?assertEqual(6, length(airspace:drones(Arena))),
    ?assertEqual(6, maps:size(Controllers)),
    %% ⚠ THE PAIRING IS THE WHOLE REPLY. A drone is `{attacker, 1}'; a genome is
    %% a sha256. Without it the defender could say who won and not WHICH of the
    %% attacker's genomes came home, and the attacker's roster could not settle.
    ?assertEqual(3, length(Pairs)),
    [?assertMatch({{attacker, _}, <<_/binary>>}, P) || P <- Pairs],
    %% Every drone in the arena has a controller: a drone without one commands
    %% nothing and would sit still inside a result that looks real.
    [?assert(maps:is_key(D#drone.id, Controllers)) || D <- airspace:drones(Arena)].

%% The raiding party flies as the ATTACKER, into the defender's volume. At item 8
%% that is where the second price lives: the defender's sensor network covers
%% this airspace and the raider's covers nothing.
the_raiders_are_the_attacking_side_test() ->
    {ok, Arena, _C, Pairs} = defence:compose(defenders(2), raiders(2), 3),
    Att = [D#drone.id || D <- airspace:drones(Arena), D#drone.side =:= attacker],
    ?assertEqual(lists:sort(Att), lists:sort([Id || {Id, _G} <- Pairs])).

an_empty_side_is_refused_rather_than_flown_test() ->
    ?assertEqual({error, no_defenders}, defence:compose([], raiders(2), 0)),
    ?assertEqual({error, no_raiders}, defence:compose(defenders(2), [], 0)).

%%==============================================================================
%% Settling
%%==============================================================================

%% ⚠ WITHDRAWN IS NOT DEAD. `airspace:survivors/1' is every drone still alive, and
%% a raider that judged the fight lost and broke off is alive. That is the entire
%% reason the withdraw actuator exists, and reporting it as a loss would price
%% retreating the same as dying.
a_withdrawn_raider_comes_home_test() ->
    Pairs = [{{attacker, 1}, <<"g1">>}, {{attacker, 2}, <<"g2">>}],
    Result = #{survivors => [{attacker, 1}], winner => defender},
    ?assertEqual([{<<"g1">>, survived}, {<<"g2">>, lost}], defence:fates(Pairs, Result)),
    ?assertEqual(defender, defence:outcome(Result)).

a_result_with_nothing_in_it_is_a_draw_and_a_total_loss_test() ->
    Pairs = [{{attacker, 1}, <<"g1">>}],
    ?assertEqual([{<<"g1">>, lost}], defence:fates(Pairs, #{})),
    ?assertEqual(draw, defence:outcome(#{})).

%%==============================================================================
%% End to end, in one process
%%==============================================================================

%% ⚠ THE ONE THAT PROVES THE PIECES FIT. Two independently seeded rosters, a
%% composed engagement actually flown, and fates that name genomes rather than
%% drones. Everything except the mesh.
a_whole_raid_can_be_flown_and_settled_test_() ->
    {timeout, 120, fun () ->
        Raiders = raiders(3),
        {ok, Arena, Controllers, Pairs} = defence:compose(defenders(3), Raiders, 5),
        Result = engagement:run(Arena, Controllers),
        Fates = defence:fates(Pairs, Result),

        ?assertEqual(3, length(Fates)),
        ?assert(lists:member(defence:outcome(Result), [attacker, defender, draw])),
        [?assert(lists:member(F, [survived, lost])) || {_Id, F} <- Fates],
        %% Every fate names a genome the attacker actually sent, which is what
        %% lets `raid:settle/3' put the right survivors back.
        Sent = [Id || {Id, _G} <- Raiders],
        [?assert(lists:member(Id, Sent)) || {Id, _F} <- Fates]
    end}.
