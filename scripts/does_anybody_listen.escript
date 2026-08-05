#!/usr/bin/env escript
%%! -sname dronex_listen
%%
%% Breed for a while, then ask whether the radio is load-bearing.
%%
%% ==========================================================================
%% ⚠ THIS IS A SMOKE CHECK ON THE INSTRUMENT, NOT AN ANSWER
%% ==========================================================================
%%
%% `Do drones evolve a signalling convention' is a CLAIM about the world, and
%% CLAUDE.md is explicit that a claim gets pre-registration and an adversarial
%% gate before anybody writes a runner. This script does not make that claim and
%% must not be quoted as evidence for it: a few hundred rounds on a laptop is
%% nowhere near the exposure such a claim would need.
%%
%% What it IS for is the thing that has to be true before the claim can even be
%% asked, and that is a BUILD question:
%%
%%     do the three numbers move, and can they be read
%%
%% The failure it exists to catch is the one that already happened once during
%% item 6, when `radio.erl' was written into a directory that did not exist and
%% everything downstream compiled cleanly BECAUSE the module was absent. A silent
%% zero from an instrument that is not connected looks exactly like a silent zero
%% from a channel nobody uses.
%%
%% Usage:
%%   ERL_LIBS=$PWD/_build/default/lib scripts/does_anybody_listen.escript
%%   ERL_LIBS=$PWD/_build/default/lib scripts/does_anybody_listen.escript 300 24 6

main(Args) ->
    {Rounds, Pop, Starts} = opts(Args),
    io:format("~nBreeding ~p controllers for ~p rounds, then ablating over ~p~n",
              [Pop, Rounds, Starts]),
    io:format("swarm engagements of ~p against ~p.~n~n", [per_side(), per_side()]),
    S0 = rand:seed_s(exsss, {20260805, 6, 6}),
    {R0, S1} = trainer:seed_roster(roster:new(probe, Pop), Pop, S0),
    io:format("  ~-8s ~-9s ~-9s ~-11s ~-9s ~s~n",
              ["round", "volume", "entropy", "delta air", "delta all", "baseline"]),
    show(0, R0, Starts),
    Rn = loop(R0, S1, 1, Rounds, Starts),
    io:format("~n"),
    read(measure(Rn, Starts)),
    ok.

opts([]) -> {200, 24, 4};
opts([R]) -> {list_to_integer(R), 24, 4};
opts([R, P]) -> {list_to_integer(R), list_to_integer(P), 4};
opts([R, P, S | _]) -> {list_to_integer(R), list_to_integer(P), list_to_integer(S)}.

%% ⚠ THREE A SIDE, BECAUSE A DUEL CANNOT ANSWER THE QUESTION. With one drone on
%% each side there is no friendly to talk to, the friendly bank is structurally
%% zero, and muting it cannot change anything. A duel would report `comms do not
%% matter' with perfect consistency and it would be an artefact of the formation.
per_side() -> 3.

loop(R, _S, N, Rounds, _Starts) when N > Rounds -> R;
loop(R, S, N, Rounds, Starts) ->
    {R1, _Report, S1} = trainer:round(R, #{rand => S, tick => N, island => probe}),
    maybe_show(N, Rounds, R1, Starts),
    loop(R1, S1, N + 1, Rounds, Starts).

maybe_show(N, Rounds, R, Starts) -> shown(N rem max(1, Rounds div 5), N, R, Starts).

shown(0, N, R, Starts) -> show(N, R, Starts);
shown(_Other, _N, _R, _Starts) -> ok.

show(N, R, Starts) ->
    Rep = measure(R, Starts),
    #{mean := E} = maps:get(entropy, Rep),
    #{air := Air, all := All} = maps:get(delta, Rep),
    io:format("  ~-8b ~-9b ~-9b ~-11b ~-9b ~b%~n",
              [N, maps:get(volume, Rep), E, Air, All, maps:get(baseline, Rep)]).

%%==============================================================================
%% The measurement
%%==============================================================================

measure(R, Starts) -> against(roster:best(R), second(R), Starts).

against(undefined, _Other, _Starts) -> ablation:measure([]);
against(_Best, undefined, _Starts) -> ablation:measure([]);
against(Best, Other, Starts) ->
    ablation:measure(fights(roster:entry_genome(Best),
                            roster:entry_genome(Other), Starts)).

%% Best against the next entry down, so the pair is deterministic rather than
%% drawn and the row is reproducible.
second(R) ->
    Best = roster:best(R),
    others([E || E <- roster:entries(R),
                 roster:entry_id(E) =/= roster:entry_id(Best)]).

others([E | _]) -> E;
others([]) -> undefined.

fights(Mine, Theirs, Starts) ->
    [fight(Mine, Theirs, I) || I <- lists:seq(0, Starts - 1)].

fight(Mine, Theirs, Index) ->
    Placed = drone_starts:place(per_side(), per_side(), Index),
    Cs = maps:from_list([{Id, crew(Side, Mine, Theirs)}
                         || {Id, Side, _, _, _, _} <- Placed]),
    {airspace:new(Placed), Cs}.

%% A fresh controller per drone: a pilot carries recurrent state, and sharing one
%% would make three drones behave as one animal.
crew(attacker, Mine, _Theirs) -> element(2, engagement:controller(Mine));
crew(defender, _Mine, Theirs) -> element(2, engagement:controller(Theirs)).

%%==============================================================================
%% Reading it
%%==============================================================================

%% ⚠ EACH ZERO MEANS SOMETHING DIFFERENT AND THE READING IS SPELLED OUT, because
%% the tempting summary is a single verdict line and there isn't one.
read(Rep) ->
    #{mean := E, channel := Per} = maps:get(entropy, Rep),
    #{air := Air, ground := Ground, all := All} = maps:get(delta, Rep),
    Vol = maps:get(volume, Rep),
    io:format("  after ~p engagements over ~p ticks:~n~n",
              [maps:get(engagements, Rep), maps:get(ticks, Rep)]),
    io:format("    signal volume     ~-10b ~s~n", [Vol, volume_says(Vol)]),
    io:format("    channel entropy   ~-10b ~s~n", [E, entropy_says(E)]),
    io:format("      per channel     ~p of ~p max~n", [Per, ablation:max_entropy()]),
    io:format("    delta, air muted  ~-10b ~s~n", [Air, delta_says(Air, Vol)]),
    io:format("    delta, ground     ~-10b ~s~n", [Ground, ground_says(Ground)]),
    io:format("    delta, all muted  ~-10b ~s~n~n", [All, delta_says(All, Vol)]),
    io:format("  ~s~n", [caveat()]),
    io:format("RESULT volume=~p entropy=~p air=~p ground=~p all=~p void=~p~n",
              [Vol, E, Air, Ground, All, maps:get(void, Rep)]).

volume_says(0) -> "NOTHING WAS SAID. Every line below is void, not null.";
volume_says(_V) -> "the channel is being driven".

entropy_says(0) -> "driven with a CONSTANT, which is silence in a signal's clothes";
entropy_says(_E) -> "the transmissions vary".

delta_says(_D, 0) -> "void: see the volume line";
delta_says(0, _V) -> "driven, varied, and depended on by nothing";
delta_says(D, _V) when D > 0 -> "silencing this side costs it";
delta_says(_D, _V) -> "silencing this side HELPS it, which is worth explaining".

ground_says(0) -> "expected: the static defence has no transmitter until item 8";
ground_says(_D) -> "UNEXPECTED before item 8, and worth stopping for".

caveat() ->
    "A short run on one seed. Charter rule 3: nothing is tuned on this, and no "
    "claim about evolved signalling rests on it.".
