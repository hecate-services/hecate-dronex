%% @doc What a drone hears. PURE.
%%
%% THIS EXISTS SO A SWARM CAN BE MORE THAN THE SUM OF THE DRONES IN IT, AND SO
%% THAT WHETHER IT ACTUALLY IS CAN BE MEASURED RATHER THAN ADMIRED.
%%
%% ==========================================================================
%% ⚠ THIS IS A COOPERATION QUESTION, NOT THE ARMS-RACE ONE P7 CLOSED
%% ==========================================================================
%%
%% Programme P7 closed on a negative at insight 062 and this repository's charter
%% takes that seriously. But P7 asked about ESCALATION between two adapting
%% sides: does an arms race happen, does the interaction cycle, does a co-adapting
%% opponent buy anything a diverse static one does not. The answers were no.
%%
%% Signalling WITHIN a swarm is a different question with different literature and
%% different failure modes, and nothing in P7 speaks to it. The nearest relevant
%% prior work is the evolution of signalling under conflicting interests, where
%% the interesting finding is that public signals with divergent interests select
%% for information SUPPRESSION rather than for richer language.
%%
%% ==========================================================================
%% THREE DECISIONS, EACH OF WHICH COULD HAVE RUINED IT
%% ==========================================================================
%%
%% THE SUM, NOT A SLOT PER DRONE. Fixed slots by drone index break the moment a
%% drone dies and tie a controller to one swarm size. A sum is invariant to
%% ordering, fixed in width whatever the swarm size, degrades gracefully as drones
%% are lost, and its MAGNITUDE carries a crude count of how many are shouting.
%% That last part is why it is a sum rather than a mean: a mean throws the count
%% away. It also means one population of genomes flies as a swarm of four or of
%% twelve without per-slot specialists, which the roster needs.
%%
%% THE ENEMY HEARS YOU. Radio is broadcast and interceptable, so signalling is a
%% trade between coordinating with your own side and disclosing to the other, and
%% neither term is free. A swarm that goes silent under contact has discovered
%% something; so has one that transmits harder.
%%
%% ⚠ THREE BANKS RATHER THAN TWO, AND THE ARGUMENT IS THE INSTRUMENT. Putting the
%% ground network's transmissions in the friendly bank would cost nothing and
%% would make muting comms mute cueing too, so `drones coordinating with each
%% other' and `drones being cued from the ground' would stop being separable.
%% They are different findings. See `ablation'.
-module(radio).

-include("airspace.hrl").

-export([heard/2, heard/3, banks/0, width/0, silence/0, volume/1]).

%% Four channels per bank, three banks: friendly air, hostile air, ground.
-define(BANK, 4).
-define(BANKS, 3).

-spec banks() -> pos_integer().
banks() -> ?BANKS.

-spec width() -> pos_integer().
width() -> ?BANK * ?BANKS.

-spec silence() -> [integer()].
silence() -> lists:duplicate(width(), 0).

%% @doc The twelve integers one drone hears this tick.
-spec heard(#drone{}, [#drone{}]) -> [integer()].
heard(Self, Others) -> heard(Self, Others, none).

%% @doc As above, with a bank silenced.
%%
%% ⚠ THE MUTE IS HERE RATHER THAN IN A COPY OF THE ENGINE, so an ablated replay
%% differs from the real one in exactly one respect and nothing else. A second
%% code path would be a second engine, and the two would drift.
-spec heard(#drone{}, [#drone{}], none | air | ground | all) -> [integer()].
heard(#drone{} = Self, Others, Mute) ->
    Audible = [O || O <- Others, in_earshot(Self, O)],
    muted(air, Mute, sum([O#drone.signal || O <- Audible, friendly(Self, O)]))
        ++ muted(air, Mute, sum([O#drone.signal || O <- Audible, not friendly(Self, O)]))
        %% ⚠ ZERO UNTIL ITEM 8, AND CARRIED ANYWAY. The genome's width is fixed by
        %% the channel count, so growing it when the static defence lands would
        %% invalidate every genome bred and persisted before it.
        ++ muted(ground, Mute, lists:duplicate(?BANK, 0)).

muted(_Bank, none, Values) -> Values;
muted(Bank, Bank, _Values) -> lists:duplicate(?BANK, 0);
muted(_Bank, all, _Values) -> lists:duplicate(?BANK, 0);
muted(_Bank, _Other, Values) -> Values.

%% @doc How loud one drone is, for the instrument that asks whether anything was
%% ever said. Zero over a whole engagement invalidates any claim about
%% coordination rather than producing a null.
-spec volume(#drone{}) -> non_neg_integer().
volume(#drone{signal = S}) -> lists:sum([abs(V) || V <- S]).

%% A drone that is dead or has left cannot transmit, and a drone never hears
%% itself: its own signal is already the thing it chose, not information.
in_earshot(#drone{id = Id}, #drone{id = Id}) -> false;
in_earshot(_Self, #drone{dead = true}) -> false;
in_earshot(_Self, #drone{withdrawn = true}) -> false;
in_earshot(#drone{x = X, y = Y, z = Z}, #drone{x = Ox, y = Oy, z = Oz}) ->
    #{comms_range := R} = airspace:limits(),
    fixed:mag3(Ox - X, Oy - Y, Oz - Z) =< R.

friendly(#drone{side = S}, #drone{side = S}) -> true;
friendly(_Self, _Other) -> false.

%% Clamped, so a large swarm saturates rather than handing a controller a number
%% it has never seen at any other swarm size.
sum(Signals) -> [bound(V) || V <- totals(Signals, lists:duplicate(?BANK, 0))].

totals([], Acc) -> Acc;
totals([S | Rest], Acc) when is_list(S), length(S) =:= ?BANK ->
    totals(Rest, [A + B || {A, B} <- lists:zip(Acc, S)]);
totals([_Malformed | Rest], Acc) -> totals(Rest, Acc).

bound(V) ->
    #{heard_max := Max} = airspace:limits(),
    fixed:clamp(V, -Max, Max).
