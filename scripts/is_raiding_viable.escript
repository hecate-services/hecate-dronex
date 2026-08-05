#!/usr/bin/env escript
%%! -pa _build/default/lib/hecate_dronex/ebin

%% Is there still a game, at the physics this build was compiled with?
%%
%% ⚠ THIS ANSWERS THE ONE QUESTION ITEM 8 OWES. `design/DESIGN_THE_STATIC_DEFENCE.md'
%% names the failure it most fears and writes the criterion down BEFORE the dial
%% is set: **a competent attacking swarm must win a non-trivial fraction of raids
%% against a competent defence.** If home advantage is overwhelming, every island
%% turtles, no genomes cross, and the charter's one idea dies quietly while the
%% exhibit still looks busy.
%%
%% One arm of the sweep. `scripts/sweep_the_defence.sh' recompiles the physics
%% and runs this once per setting.
%%
%% ==========================================================================
%% ⚠⚠ THE CRITERION IS FIXED HERE, ABOVE THE CODE, BEFORE ANY OF IT RUNS
%% ==========================================================================
%%
%%   competence  the best entry on each side must win at least 40% of its
%%               frozen-benchmark starts. Without this, two incompetent swarms
%%               produce a beautiful 50% and it means nothing at all: coin flips
%%               look exactly like a balanced game.
%%
%%   viability   the attacker must take between 20% and 80% of raids.
%%               Below 20% the defence has closed the game and islands turtle.
%%               Above 80% the defence is decoration and the raid is a formality.
%%
%% ⚠⚠⚠ AND THE SETTING IS NEVER CHOSEN BY WHICHEVER ARM GAVE A NUMBER SOMEBODY
%% LIKED. Charter rule 3. The sweep prints every arm, including the ones that
%% killed the game, and the one that reports `viable=false' everywhere is a
%% finding rather than a failed run.
%%
%% Usage:
%%   ERL_LIBS=$PWD/_build/default/lib scripts/is_raiding_viable.escript
%%
%% Environment, so the driver can trade cost against confidence:
%%   SWEEP_GENERATIONS  breeding rounds per island   (default 60)
%%   SWEEP_RAIDS        raids per direction          (default 8)
%%   SWEEP_SEED         base seed, so an arm repeats (default 20260806)

-mode(compile).

%% The roster must stay above the raid floor after mustering a party, or
%% `raid:sortie/3' refuses and the arm measures nothing. Floor is 60 and a party
%% is 12, so anything below 72 cannot raid at all.
-define(SEED_DEPTH, 84).

main(_Args) ->
    Gens = env("SWEEP_GENERATIONS", 60),
    Raids = env("SWEEP_RAIDS", 8),
    Base = env("SWEEP_SEED", 20260806),
    Started = erlang:monotonic_time(second),

    banner(Gens, Raids),

    %% ⚠ EACH SIDE TRAINS UNDER THIS ARM'S PHYSICS, AND THAT IS THE WHOLE REASON
    %% THIS IS SLOW. A swarm bred under five towers is not the swarm you would
    %% get under two, so carrying one pre-trained roster across every arm would
    %% measure "how does THIS swarm fare against various defences" — an
    %% interesting question, and not the one the criterion asks. The criterion
    %% says COMPETENT attacker against COMPETENT defence, and competence is
    %% relative to the world you were bred in.
    {Alpha, SeedA} = trained(alpha, Gens, {Base, 1, 1}),
    {Bravo, SeedB} = trained(bravo, Gens, {Base, 2, 2}),

    CompA = competence(Alpha),
    CompB = competence(Bravo),

    %% Both directions, because "attacker" is a role and not a side. An arm that
    %% only ever ran alpha against bravo would be measuring the two rosters as
    %% much as the physics.
    Out = duel(Alpha, Bravo, Raids, Base) ++ duel(Bravo, Alpha, Raids, Base + 500),

    report(Out, {SeedA, CompA}, {SeedB, CompB},
           erlang:monotonic_time(second) - Started).

%%==============================================================================
%% Breeding a competent island
%%==============================================================================

%% ⚠ THE SCORE BEFORE BREEDING IS RETURNED TOO, AND IT IS NOT DECORATION. Eighty
%% random genomes and then taking the BEST of them is already a selection step,
%% so a seeded roster scores well above zero on the frozen ladder before a single
%% round is bred — 53% was observed at two rounds. Without the before-number
%% there is no way to tell a competence gate that is doing its job from one every
%% arm walks through, and an arm where breeding moved competence by nothing is a
%% finding about the generation budget rather than about the defence.
trained(Name, Gens, Seed) ->
    R0 = roster:new(Name, 240),
    {R1, S1} = trainer:seed_roster(R0, ?SEED_DEPTH, rand:seed_s(exsss, Seed)),
    Before = competence(R1),
    io:format("  ~-6s seeded ~w at ~w%, breeding ~w rounds",
              [Name, roster:depth(R1), Before, Gens]),
    R2 = grind(R1, S1, Gens),
    io:format(" -> depth ~w~n", [roster:depth(R2)]),
    {R2, Before}.

grind(R, _S, 0) -> R;
grind(R, S, N) ->
    {R1, _Stats, S1} = trainer:round(R, #{rand => S}),
    grind(R1, S1, N - 1).

%% ⚠ MEASURED ON THE FROZEN BENCHMARK, WHICH IS AN AWAY GAME WITH NO NETWORK.
%% That is what makes competence comparable ACROSS arms: it scores the
%% controller and never the terrain, so a swarm bred under a strong defence and
%% one bred under a weak defence are held to the same exam. Scoring competence
%% by anything that involved the towers would make every arm its own yardstick.
competence(R) -> scored(roster:best(R)).

scored(undefined) -> 0;
scored(Entry) -> profiled(benchmark:sit(roster:entry_genome(Entry))).

profiled({error, _Why}) -> 0;
profiled({ok, #{wins := Wins, rungs := Rungs, starts := Starts}}) ->
    total(lists:sum(Wins), length(Rungs) * Starts).

total(_W, 0) -> 0;
total(W, N) -> (W * 100) div N.

%%==============================================================================
%% The raids
%%==============================================================================

duel(Att, Def, Raids, Seed) ->
    [one(Att, Def, N, rand:seed_s(exsss, {Seed, N, N})) || N <- lists:seq(1, Raids)].

%% Exactly what production does: both parties are `raid:sortie/3' off the
%% roster, the start geometry is an index, and the defender hosts with its
%% network up while the raider flies in with none.
one(Att, Def, Index, S) ->
    {Party, _Att1, S1} = raid:sortie(Att, S, raid:party()),
    {Held, _Def1, _S2} = raid:sortie(Def, S1, raid:party()),
    Raiders = [{roster:entry_id(E), roster:entry_genome(E)} || E <- Party],
    fought(defence:compose(Held, Raiders, Index rem drone_starts:count())).

fought({error, Why}) -> {error, Why};
fought({ok, Arena, Controllers, _Pairs}) ->
    defence:outcome((defence:host(Controllers))(Arena)).

%%==============================================================================
%% The report
%%==============================================================================

banner(Gens, Raids) ->
    #{sensors := N, sensor_range := R, arena_z := Z} = airspace:limits(),
    io:format("~n  arm: sensors=~w reach=~wm ceiling=~wm  (~w rounds, ~w raids each way)~n",
              [N, R div 20480, Z div 20480, Gens, Raids]).

report(Out, {SeedA, CompA}, {SeedB, CompB}, Secs) ->
    Errors = [W || {error, W} <- Out],
    Played = [O || O <- Out, not is_tuple(O)],
    Att = length([O || O <- Played, O =:= attacker]),
    Def = length([O || O <- Played, O =:= defender]),
    Draw = length([O || O <- Played, O =:= draw]),
    Rate = total(Att, length(Played)),
    Competent = CompA >= 40 andalso CompB >= 40,
    Viable = Competent andalso Rate >= 20 andalso Rate =< 80,

    io:format("  competence  alpha ~w% (from ~w%)  bravo ~w% (from ~w%)   (floor 40%)~n",
              [CompA, SeedA, CompB, SeedB]),
    io:format("  raids       attacker ~w  defender ~w  draw ~w  refused ~w~n",
              [Att, Def, Draw, length(Errors)]),
    io:format("  attacker takes ~w% of ~w raids, in ~w s~n", [Rate, length(Played), Secs]),
    verdict(Competent, Viable),

    %% ⚠ ONE MACHINE-READABLE LINE, AND THE DRIVER READS ONLY THIS. Parsing a
    %% sibling's prose went wrong twice on the interceptor sweep — once taking
    %% the criterion thresholds for results, once on Erlang printing a doubled
    %% percent sign. A script that reads another script's formatting is a mirror
    %% of that formatting.
    #{sensors := N, sensor_range := R, arena_z := Z} = airspace:limits(),
    io:format("RESULT sensors=~w reach=~w ceiling=~w compa=~w compb=~w "
              "seeda=~w seedb=~w "
              "att=~w def=~w draw=~w refused=~w rate=~w competent=~w viable=~w secs=~w~n",
              [N, R div 20480, Z div 20480, CompA, CompB, SeedA, SeedB,
               Att, Def, Draw, length(Errors), Rate, Competent, Viable, Secs]).

verdict(false, _V) ->
    io:format("  VERDICT  neither side is competent yet: the rate is a coin flip, not a game~n");
verdict(true, true) ->
    io:format("  VERDICT  viable~n");
verdict(true, false) ->
    io:format("  VERDICT  one side has closed the game~n").

env(Name, Default) ->
    parsed(os:getenv(Name), Default).

parsed(false, Default) -> Default;
parsed("", Default) -> Default;
parsed(V, Default) ->
    try list_to_integer(V) catch _:_ -> Default end.
