%% @doc The raid, as arithmetic on rosters. PURE.
%%
%% THIS EXISTS SO THAT LOSING A RAID COSTS SOMETHING AND WINNING ONE TEACHES
%% SOMEBODY.
%%
%% ==========================================================================
%% ⚠ A RAID NEVER ASSIGNS FITNESS. THAT IS THE CHARTER'S ONE IDEA
%% ==========================================================================
%%
%% Insight 057 found that a co-adapting opponent buys nothing a diverse static
%% one does not. Taken literally rather than as a discouragement, that makes a
%% raid a DIVERSITY PUMP FOR THE TRAINING CURRICULUM and not a selection
%% pressure. Selection stays local, against an opponent set that raids widen.
%%
%% So nothing in this module writes a fitness. What it does is move genomes:
%% out of the attacker's roster, into the defender's opponent set, and — for the
%% ones that come home — back again. Wiring a raid outcome into fitness would be
%% building the exact thing 057 refuted, and it would be one line.
%%
%% ==========================================================================
%% ⚠⚠ A GENOME IS SPENT WHEN IT FLIES, AND THAT IS THE ONLY PRICE THERE IS
%% ==========================================================================
%%
%% Sending twelve drones REMOVES twelve entries. Survivors are returned, the dead
%% are not, and refilling means breeding, which costs ticks the trainer would
%% otherwise spend improving. Without it a defeated attacker rebuilds from an
%% archive at no cost and the exhibit becomes islands raiding, losing, rebuilding
%% and raiding again while nothing selects — stasis wearing the costume of
%% activity, which is the failure this design is most at risk of.
%%
%% The defender pays on the same terms. An island that is popular gets ground
%% down by attention, and that is not compensated with an invented reward: what
%% it gets is the attacker's genomes, which is worth more than airframes.
-module(raid).

-export([sortie/3, target/2, settle/3, absorb/3]).
-export([floor_of/0, party/0]).

%% ⚠ THE FLOOR STOPS AN ISLAND RAIDING ITSELF TO EXTINCTION, which is a real risk
%% the moment genomes are spent by flying, and is the local form of what killed
%% every configuration in insight 062. Below it, an island stays home and breeds.
-define(ROSTER_FLOOR, 60).

%% How many leave on one sortie. Small against a roster of 240 so a raid is a
%% cost rather than a gamble of the whole lineage.
-define(PARTY, 6).

-spec floor_of() -> pos_integer().
floor_of() -> ?ROSTER_FLOOR.

-spec party() -> pos_integer().
party() -> ?PARTY.

%%==============================================================================
%% Leaving
%%==============================================================================

%% @doc Take a raiding party out of the roster. They are GONE until they return.
%%
%% ⚠ REMOVED, NOT COPIED, AND NOT MARKED. A flag saying "away" would leave the
%% genome available to the trainer as a parent and to a defender as an opponent
%% while it is supposedly airborne, so an island would field the same controller
%% in two places at once and the roster's finiteness — the whole price — would be
%% decorative.
-spec sortie(roster:roster(), rand:state(), pos_integer()) ->
    {[roster:entry()], roster:roster(), rand:state()}.
sortie(R, S, N) ->
    grounded(roster:depth(R) - N >= ?ROSTER_FLOOR, R, S, N).

grounded(false, R, S, _N) -> {[], R, S};
grounded(true, R, S, N) ->
    {Party, S1} = roster:sample(R, N, S),
    {Taken, R1} = roster:take(R, [roster:entry_id(E) || E <- Party]),
    {Taken, counted(R1, Taken), S1}.

%% A sortie is counted on the roster that stays behind, so an island's record of
%% how often it has attacked survives the party not coming back.
counted(R, Taken) ->
    lists:foldl(fun (E, Acc) -> roster:count_sortie(Acc, roster:entry_id(E)) end, R, Taken).

%% @doc Whom to attack: an island heard from recently, never oneself.
%%
%% ⚠ A TARGET IS CHOSEN FROM ISLANDS THIS ONE HAS HEARD PUBLISH. That is not a
%% protection, it is a consequence: there is no directory, and the public realm is
%% the only place islands become visible to each other. An island that is silent
%% is not attacked, and an island that raids is by definition one that listens.
-spec target([binary()], binary()) -> {ok, binary()} | none.
target(Heard, Self) -> chosen([H || H <- Heard, H =/= Self]).

chosen([]) -> none;
chosen(Others) -> {ok, hd(Others)}.

%%==============================================================================
%% Coming home
%%==============================================================================

%% @doc Put the survivors back, and only the survivors.
%%
%% ⚠ A RETURNING GENOME IS THE ONE THAT TOOK OFF. Under the design's arm L it
%% would be the weights it came home WITH, and this engine cannot do that: see
%% REGISTER D.11. Arm W is therefore not a choice that was made here, it is the
%% only arm that exists, and saying so is better than a dial with a dead position.
%%
%% Surviving is EVIDENCE ABOUT a genome rather than a change to it, so what a
%% veteran carries is a mark, not a mutation.
-spec settle(roster:roster(), [roster:entry()], [{binary(), dronex_raid:fate()}]) ->
    {roster:roster(), non_neg_integer(), non_neg_integer()}.
settle(R, Party, Fates) ->
    Home = [E || E <- Party, survived(roster:entry_id(E), Fates)],
    {lists:foldl(fun (E, Acc) -> readmit(Acc, E) end, R, Home), length(Home),
     length(Party) - length(Home)}.

survived(Id, Fates) -> lists:member({Id, survived}, Fates).

readmit(R, E) -> admitted(roster:admit(R, E), R).

admitted({admitted, R}, _Was) -> R;
%% A roster that filled up while the party was away keeps what it bred. The
%% survivor is lost, which is a real cost of having been elsewhere, and it is
%% quieter than evicting something the trainer earned in the meantime.
admitted({refused, _Why}, Was) -> Was.

%%==============================================================================
%% What the defender keeps
%%==============================================================================

%% @doc Take the attacker's genomes into this island's roster permanently.
%%
%% ⚠ THIS IS THE BEST PART AND THE WHOLE POINT. A raid delivers controllers bred
%% by a population this island has never seen, under selection pressures it did
%% not choose. They enter the opponent set — `trainer:opponents/1' is every roster
%% entry — so the local trainer now has to beat them.
%%
%% That is the mechanism by which the archipelago is more than several separate
%% experiments, and it is a use of coevolution 057's refusal does not touch,
%% because what crosses is DIVERSITY rather than a coupled opponent.
%%
%% ⚠⚠ AND IT MEANS TO RAID IS TO PUBLISH YOUR SWARM, permanently, to whoever you
%% attacked. An island that raids constantly hands its lineage to everyone it
%% touches; one that never raids evolves in a mirror. There is no free answer,
%% which is what makes it worth watching, and it is disclosed in README.md
%% because a sender cannot infer it from `send a swarm, get a result'.
-spec absorb(roster:roster(), [{binary(), drone_genome:genome()}], map()) -> roster:roster().
absorb(R, Genomes, Meta) ->
    lists:foldl(fun ({Id, G}, Acc) -> captured(Acc, Id, G, Meta) end, R, Genomes).

captured(R, Id, G, Meta) -> kept(roster:has(R, Id), R, G, Meta).

%% Already here: an island that is raided twice by the same swarm does not hold
%% it twice, and re-admitting would reset what it has since earned.
kept(true, R, _G, _Meta) -> R;
kept(false, R, G, Meta) ->
    Entry = roster:entry(G, #{origin => {captured, maps:get(from, Meta), maps:get(raid, Meta)},
                              born_at => maps:get(tick, Meta, 0),
                              generation => 0,
                              %% ⚠ ZERO FITNESS, NOT AN INHERITED ONE. A foreign
                              %% genome's fitness was measured against somebody
                              %% else's opponent set and means nothing here. It
                              %% enters as an OPPONENT and earns a local number
                              %% only if the local trainer ever sits it.
                              fitness => 0}),
    admitted(roster:admit(R, Entry), R).
