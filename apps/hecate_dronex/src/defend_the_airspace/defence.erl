%% @doc Hosting somebody else's raid. PURE.
%%
%% THIS EXISTS SO THAT THE DEFENDER RUNS THE FIGHT, AND SO THAT RUNNING IT COSTS
%% THE DEFENDER SOMETHING TOO.
%%
%% ==========================================================================
%% ⚠ THE DEFENDER HOSTS, AND THAT IS NOT A LOAD-BALANCING CHOICE
%% ==========================================================================
%%
%% One engine runs the engagement, and it is the one being attacked. If the
%% attacker simulated its own raid it would report its own result, and there is
%% nothing on the wire an honest defender could check it against: the frames
%% would be internally consistent, the physics would be the published physics,
%% and the winner would be whoever wrote the client.
%%
%% Hosting also puts the cost where the design wants it. An island that is
%% popular pays in CPU as well as in airframes, which is what `an island that is
%% popular gets ground down by attention' means when it stops being a metaphor.
%%
%% ==========================================================================
%% ⚠⚠ ATTACKER AND DEFENDER ARE THE ENGAGEMENT'S OWN SIDES, NOT A RELABELLING
%% ==========================================================================
%%
%% `drone_starts:place/3' already lays out an `attacker' side and a `defender'
%% side, and a raid maps straight onto them. The raiding party flies as the
%% attacker, into the defender's volume, which is where the second price lives:
%% at item 8 the defender's static sensor network will cover this airspace and
%% the raider's will cover nothing, because a network defends its own volume
%% only. Choosing to attack is choosing to fight without the thing that makes
%% you strong.
-module(defence).

-include("airspace.hrl").

-export([compose/3, host/1, fates/2, outcome/1, survivors/2]).

%% @doc Lay out the fight and crew both sides.
%%
%% Equal numbers: an unequal fight would make the outcome a fact about the
%% numbers rather than about the controllers, and both sides pay the same price
%% per airframe.
%% ⚠ BOTH PAIRINGS COME BACK, for the same reason the attacker's does: a drone is
%% `{defender, 2}' and a roster entry is a sha256, and the defender has to settle
%% its OWN losses too. The first version recovered the defender's side by
%% position in a list, which is a second, unwritten copy of the pairing that
%% `compose/3' already knows — and the day the layout stops being index-ordered
%% it would go on returning plausible survivors quietly.
%% @doc Fly a composed defence. AT HOME, WITH THE ISLAND'S NETWORK UP.
%%
%% ⚠ THIS LIVES HERE RATHER THAN AT THE CALL SITE, and the reason is a guard
%% probe that would not bite. How a hosted raid is fought is a fact about
%% DEFENDING, so it belongs to this slice; while it sat inline in the island
%% server it was one option map among several in a process that also runs
%% training bouts, and nothing could assert it without reading source and
%% guessing which occurrence it had found. Now the asymmetry that prices a raid
%% is one exported function with a test on it.
%%
%% The raider gets no equivalent, because a raider has no equivalent: it flies
%% into somebody else's volume with no ground support at all.
-spec host(#{term() => engagement:controller()}) -> fun((#arena{}) -> engagement:result()).
host(Controllers) ->
    fun (Arena) ->
        engagement:run(Arena, Controllers,
                       #{frames => true, network => network:home()})
    end.

-spec compose([roster:entry()], [{binary(), drone_genome:genome()}], non_neg_integer()) ->
    {ok, #arena{}, map(), #{attackers := [{term(), binary()}],
                            defenders := [{term(), roster:entry()}]}}
    | {error, term()}.
compose([], _Raiders, _Index) -> {error, no_defenders};
compose(_Defenders, [], _Index) -> {error, no_raiders};
compose(Defenders, Raiders, Index) ->
    Placed = drone_starts:place(length(Raiders), length(Defenders), Index),
    crew(Placed, sides(Placed, Defenders, Raiders)).

%% ⚠ THE MAP FROM A DRONE'S ID BACK TO A GENOME'S ID IS THE WHOLE REPLY. A drone
%% is `{attacker, 1}'; a genome is a sha256. Without this pairing the defender
%% could say who won and not WHICH of the attacker's genomes came home, and the
%% attacker's roster could not be settled at all.
sides(Placed, Defenders, Raiders) ->
    Att = lists:zip(ids(Placed, attacker), Raiders),
    Def = lists:zip(ids(Placed, defender), Defenders),
    {Att, Def}.

ids(Placed, Side) -> [Id || {Id, S, _, _, _, _} <- Placed, S =:= Side].

crew(Placed, {Att, Def}) ->
    Wanted = [{DroneId, G} || {DroneId, {_GenomeId, G}} <- Att]
             ++ [{DroneId, roster:entry_genome(E)} || {DroneId, E} <- Def],
    assembled(build(Wanted, #{}), Placed, {Att, Def}).

%% ⚠ ONE UNFLYABLE GENOME REFUSES THE WHOLE ENGAGEMENT, for the same reason
%% `dronex_raid' refuses the whole raid: the alternative is a drone with no
%% controller sitting still inside a result that looks real. The raiders were
%% already validated on arrival, so reaching this is a defender-side fault, and
%% it is still better to refuse than to fly a swarm with a hole in it.
build([], Acc) -> {ok, Acc};
build([{DroneId, G} | Rest], Acc) -> made(engagement:controller(G), DroneId, G, Rest, Acc).

made({error, Why}, DroneId, _G, _Rest, _Acc) -> {error, {unflyable, DroneId, Why}};
made({ok, C}, DroneId, _G, Rest, Acc) -> build(Rest, Acc#{DroneId => C}).

assembled({error, _} = E, _Placed, _Sides) -> E;
assembled({ok, Controllers}, Placed, {Att, Def}) ->
    {ok, airspace:new(Placed), Controllers,
     #{attackers => [{DroneId, GId} || {DroneId, {GId, _G}} <- Att],
       defenders => Def}}.

%% @doc What happened to each of the attacker's genomes, by name.
-spec fates([{term(), binary()}], map()) -> [{binary(), dronex_raid:fate()}].
fates(Pairs, Result) ->
    Survivors = maps:get(survivors, Result, []),
    [{GenomeId, fate_of(lists:member(DroneId, Survivors))} || {DroneId, GenomeId} <- Pairs].

%% ⚠ WITHDRAWN IS NOT DEAD. `airspace:survivors/1' is the list of drones still
%% alive at the end, and a drone that broke off and left under the withdraw rule
%% is alive. A raider that judged the fight lost and got out comes home, which is
%% the entire reason the withdraw actuator exists.
fate_of(true) -> survived;
fate_of(false) -> lost.

%% @doc Which of the defender's own entries are still alive, by the pairing
%% rather than by position.
-spec survivors([{term(), roster:entry()}], map()) -> [roster:entry()].
survivors(Pairs, Result) ->
    Alive = maps:get(survivors, Result, []),
    [E || {DroneId, E} <- Pairs, lists:member(DroneId, Alive)].

-spec outcome(map()) -> attacker | defender | draw.
outcome(Result) -> maps:get(winner, Result, draw).
