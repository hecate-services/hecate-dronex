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
                    %% ⚠ HOW MUCH WAS SAID, OVER THE WHOLE ENGAGEMENT. Charter
                    %% instrument: zero means nothing was ever transmitted, and a
                    %% run in which nothing was transmitted invalidates any claim
                    %% about coordination rather than producing a null.
                    signal_volume := non_neg_integer(),
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
    loop(Arena, Controllers, collector(Opts), muting(maps:get(mute, Opts, none)), 0).

%% ⚠ THE MUTE IS PER SIDE, AND MAKING IT GLOBAL WOULD HAVE PRODUCED A FALSE ZERO.
%% Silencing both sides of a self-play match leaves the win rate at about half
%% whatever the channel is worth, because whatever coordination buys, it buys for
%% both. The ablation would then report `no effect' most loudly in exactly the
%% case where comms mattered most. Muting ONE side measures what the channel is
%% worth TO that side, which is the quantity the design claims.
%%
%% A bare atom still means both, because the benchmark's opponents are scripted
%% drills that never speak, so there the two are the same thing.
muting(Bank) when is_atom(Bank) -> #{attacker => Bank, defender => Bank};
muting(Map) when is_map(Map) -> maps:merge(#{attacker => none, defender => none}, Map).

%% `false' is OFF, and off costs one function call per tick rather than a list of
%% every arena state.
collector(#{frames := true}) -> [];
collector(_Opts) -> false.

loop(A, Cs, Frames, Mute, Vol) ->
    stepped(airspace:finished(A), A, Cs, Frames, Mute, Vol).

stepped(true, A, _Cs, Frames, _Mute, Vol) -> report(A, Frames, Vol);
stepped(false, A, Cs, Frames, Mute, Vol) ->
    {Intents, Next} = commanded(A, Cs, Mute),
    Advanced = airspace:step(A, Intents),
    loop(Advanced, Next, kept(Frames, Advanced), Mute, Vol + said(Advanced)).

%% Counted after the step, so it is what was actually transmitted rather than
%% what was commanded: the engine clamps a signal exactly as it clamps thrust.
%% Dead and departed drones keep their last signal in the record and are excluded
%% from what anyone hears, so counting them here would credit a silent sky with
%% traffic.
said(A) ->
    lists:sum([radio:volume(D) || D <- airspace:drones(A), not gone(D)]).

kept(false, _A) -> false;
kept(Frames, A) -> [A | Frames].

%% ⚠ EVERY CONTROLLER IS ASKED BEFORE ANY OF THEM MOVES, which is what makes the
%% tick simultaneous. Advancing each drone as its command arrived would let the
%% first drone in the list see the world after nobody had moved and the last see
%% it after everybody had, so list order would be an advantage and a swarm's
%% behaviour would depend on how its roster happened to be sorted.
commanded(A, Cs, Mute) ->
    Ds = [D || D <- airspace:drones(A), not gone(D)],
    lists:foldl(fun (D, Acc) -> ask(D, Ds, Cs, Mute, Acc) end, {#{}, Cs}, Ds).

gone(#drone{dead = true}) -> true;
gone(#drone{withdrawn = true}) -> true;
gone(#drone{}) -> false.

%% ⚠ WHAT IT HEARS IS COMPUTED FROM THE DRONES AS THEY ARE NOW, AND THEIR SIGNALS
%% WERE SET BY THE PREVIOUS STEP. That is where the one-tick delay comes from, and
%% it is a consequence of the data flow rather than a timer somebody has to
%% remember to keep.
ask(#drone{id = Id, side = Side} = D, Ds, Cs, Mute, {Intents, Next}) ->
    Others = others(Id, Ds),
    answered(Id, maps:get(Id, Cs, undefined), D, Others,
             radio:heard(D, Others, maps:get(Side, Mute)), {Intents, Next}).

others(Id, Ds) -> [O || O <- Ds, O#drone.id =/= Id].

%% A drone with no controller commands nothing. That is not a defensive
%% crouch: it is what a drone whose genome was refused looks like, and it must
%% be a shape the loop can carry rather than a crash on a fleet node.
answered(_Id, undefined, _D, _Others, _Heard, Acc) -> Acc;
answered(Id, {pilot, P}, D, Others, Heard, {Intents, Next}) ->
    {I, P2} = drone_pilot:act(P, D, Others, Heard),
    {Intents#{Id => I}, Next#{Id := {pilot, P2}}};
%% ⚠ A DRILL HEARS AND NEVER SPEAKS, and that is stated rather than incidental.
%% The scripted rungs are deliberately silent, so the HOSTILE bank is zero
%% throughout the frozen exam. Any reading of what a controller does with hostile
%% traffic has to come from a raid or from self-play, never from the benchmark.
answered(Id, {drill, Dr}, D, Others, Heard, {Intents, Next}) ->
    {I, Dr2} = drone_drills:act(Dr, D, Others, Heard),
    {Intents#{Id => I}, Next#{Id := {drill, Dr2}}}.

report(A, Frames, Vol) ->
    #{winner => settled(airspace:winner(A)),
      ticks => airspace:tick_of(A),
      survivors => [D#drone.id || D <- airspace:survivors(A)],
      withdrawn => [D#drone.id || D <- airspace:drones(A), D#drone.withdrawn],
      signal_volume => Vol,
      frames => ordered(Frames)}.

ordered(false) -> false;
ordered(Frames) -> lists:reverse(Frames).

%% `undecided' cannot reach here, because the loop only stops when the arena says
%% it is finished. Collapsing it to a draw rather than letting it through is what
%% stops a caller having to handle a state that does not occur.
settled(undecided) -> draw;
settled(W) -> W.
