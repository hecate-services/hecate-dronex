%% @doc Run an engagement to its end and report what happened. PURE.
%%
%% THIS EXISTS SO THE BENCHMARK, THE TRAINER AND A RAID ALL RUN THE SAME FIGHT.
%% A sibling shipped two copies of its match loop, one in the service and one in
%% the viewer, and its own notes call that one refactor away from showing a fight
%% nobody actually fought. There is one loop here and everything goes through it.
%%
%% ⚠ FRAMES ARE OFF BY DEFAULT AND THAT IS NOT A MICRO-OPTIMISATION. A benchmark
%% is 288 engagements of up to 1200 ticks; accumulating an arena per tick would
%% allocate 345,000 of them to throw all but the last away. A raid switches them
%% on because a raid is watched.
-module(engagement).

-include("airspace.hrl").

-export([run/2, run/3, controller/1]).

-export_type([controller/0, result/0]).

%% A controller is either an evolved genome or a scripted drill. Both answer
%% `act/4' with the same shape, which is what lets one loop drive either.
-type controller() :: {pilot, drone_pilot:pilot()} | {drill, drone_drills:drill()}.

-type result() :: #{winner := attacker | defender | draw,
                    ticks := non_neg_integer(),
                    survivors := [term()],
                    withdrawn := [term()],
                    frames := [#arena{}] | false}.

%% @doc Build a controller from a genome or a drill kind.
-spec controller(drone_genome:genome() | drone_drills:kind()) ->
    {ok, controller()} | {error, term()}.
controller(Kind) when is_atom(Kind) -> {ok, {drill, drone_drills:init(Kind)}};
controller(Genome) -> from_genome(drone_pilot:init(Genome)).

from_genome({ok, P}) -> {ok, {pilot, P}};
from_genome({error, _} = E) -> E.

-spec run(#arena{}, #{term() => controller()}) -> result().
run(Arena, Controllers) -> run(Arena, Controllers, #{}).

-spec run(#arena{}, #{term() => controller()}, map()) -> result().
run(Arena, Controllers, Opts) ->
    loop(Arena, Controllers, collector(Opts)).

%% `false' is OFF, and off costs one function call per tick rather than a list of
%% every arena state.
collector(#{frames := true}) -> [];
collector(_Opts) -> false.

loop(A, Cs, Frames) -> stepped(airspace:finished(A), A, Cs, Frames).

stepped(true, A, _Cs, Frames) -> report(A, Frames);
stepped(false, A, Cs, Frames) ->
    {Intents, Next} = commanded(A, Cs),
    Advanced = airspace:step(A, Intents),
    loop(Advanced, Next, kept(Frames, Advanced)).

kept(false, _A) -> false;
kept(Frames, A) -> [A | Frames].

%% ⚠ EVERY CONTROLLER IS ASKED BEFORE ANY OF THEM MOVES, which is what makes the
%% tick simultaneous. Advancing each drone as its command arrived would let the
%% first drone in the list see the world after nobody had moved and the last see
%% it after everybody had, so list order would be an advantage and a swarm's
%% behaviour would depend on how its roster happened to be sorted.
commanded(A, Cs) ->
    Ds = [D || D <- airspace:drones(A), not gone(D)],
    lists:foldl(fun (D, Acc) -> ask(D, Ds, Cs, Acc) end, {#{}, Cs}, Ds).

gone(#drone{dead = true}) -> true;
gone(#drone{withdrawn = true}) -> true;
gone(#drone{}) -> false.

ask(#drone{id = Id} = D, Ds, Cs, {Intents, Next}) ->
    answered(Id, maps:get(Id, Cs, undefined), D, others(Id, Ds), {Intents, Next}).

others(Id, Ds) -> [O || O <- Ds, O#drone.id =/= Id].

%% A drone with no controller commands nothing. That is not a defensive
%% crouch: it is what a drone whose genome was refused looks like, and it must
%% be a shape the loop can carry rather than a crash on a fleet node.
answered(_Id, undefined, _D, _Others, Acc) -> Acc;
answered(Id, {pilot, P}, D, Others, {Intents, Next}) ->
    {I, P2} = drone_pilot:act(P, D, Others, []),
    {Intents#{Id => I}, Next#{Id := {pilot, P2}}};
answered(Id, {drill, Dr}, D, Others, {Intents, Next}) ->
    {I, Dr2} = drone_drills:act(Dr, D, Others, []),
    {Intents#{Id => I}, Next#{Id := {drill, Dr2}}}.

report(A, Frames) ->
    #{winner => settled(airspace:winner(A)),
      ticks => airspace:tick_of(A),
      survivors => [D#drone.id || D <- airspace:survivors(A)],
      withdrawn => [D#drone.id || D <- airspace:drones(A), D#drone.withdrawn],
      frames => ordered(Frames)}.

ordered(false) -> false;
ordered(Frames) -> lists:reverse(Frames).

%% `undecided' cannot reach here, because the loop only stops when the arena says
%% it is finished. Collapsing it to a draw rather than letting it through is what
%% stops a caller having to handle a state that does not occur.
settled(undecided) -> draw;
settled(W) -> W.
