%% @doc The controller contract: what a host must satisfy to fly a genome.
%%
%% THIS EXISTS SO A HOST HANDED A STRANGER'S GENOME CAN ACTUALLY RUN IT. The
%% sibling line learned this the expensive way: its engine could simulate a match
%% and could not DRIVE one, because the code turning arena state into a genome's
%% inputs, and a genome's outputs into engine commands, lived in a research runner
%% in a different repository. Every rule of the game a visitor must agree to was
%% therefore unavailable to the only component that needs it.
%%
%% ==========================================================================
%% THE PERCEPTION BOUNDARY IS A SHAPE, NOT A COMMENT
%% ==========================================================================
%%
%% `act/4' takes the drone, the OTHER DRONES and the comms it heard. It never
%% receives the arena, so munitions in flight and another drone's exact state are
%% out of scope below that line and cannot be reached even by accident.
%%
%% A comment would not survive a refactor. An argument list the compiler checks
%% will, and `drone_pilot_tests' asserts the arity rather than trusting it.
%%
%% ==========================================================================
%% ⚠ THE FIGHT IS NOT BIT-IDENTICAL ACROSS RUNTIMES, AND THIS MODULE IS WHERE
%% THAT ENTERS
%% ==========================================================================
%%
%% The arena is integer and exact. The network is `faber_tweann`'s
%% `network_evaluator`, which is float, and whose `apply_activation/2` is a
%% private closed clause list ending in `math:tanh(X)`. There is no way to put a
%% table in front of it: an unknown activation atom does not fail, it silently
%% becomes libm tanh.
%%
%% Decided 2026-08-05 to keep the evaluator, with its CfC memory, its in-episode
%% plasticity and its NIF, and to give up bit-identical replay across runtimes.
%% So a raid replays exactly on a matching OTP release and libc, and approximately
%% otherwise, and divergence is confined to ONE function and bounded at about a
%% unit in the last place. `DESIGN_THE_AIRSPACE.md` states the trade and
%% `CHARTER.md` no longer claims otherwise.
-module(drone_pilot).

-include("airspace.hrl").

%% The contract a host must satisfy
-export([inputs/0, outputs/0, init/1, act/4]).
%% The pieces, exported for tests and diagnostics rather than for the loop
-export([decide/2, commands/1, from_genome/1]).

%% Ten: three thrusts, a yaw rate, two weapons, four comms channels.
-define(OUTPUTS, 10).

%% Above zero fires. The network's last layer is a tanh, so zero is its midpoint
%% and a threshold anywhere else would be an arbitrary bias one way.
-define(FIRE_ABOVE, 0.0).

-type pilot() :: #{net := term()}.
-export_type([pilot/0]).

-spec inputs() -> pos_integer().
inputs() -> drone_senses:channels().

-spec outputs() -> pos_integer().
outputs() -> ?OUTPUTS.

%% @doc A flyable controller from a validated genome.
%%
%% ⚠ IT REFUSES AN INVALID ONE RATHER THAN PADDING IT. `network_evaluator` pads a
%% short input layer in silence, so a mismatched genome would fly badly and
%% produce a result indistinguishable from a real one.
-spec init(drone_genome:genome()) -> {ok, pilot()} | {error, term()}.
init(Genome) -> admitted(drone_genome:validate(Genome), Genome).

admitted({error, _} = E, _Genome) -> E;
admitted(ok, Genome) -> {ok, #{net => from_genome(Genome)}}.

%% @doc Build the network. CfC hidden neurons, because memory is close to a
%% prerequisite here: a signal that cannot be held is a reflex, a contact that
%% leaves the cone cannot be tracked without state, and leading a target needs to
%% know where it was.
%% ⚠ THE TIME CONSTANTS ARE SET EXPLICITLY, AND FORGETTING TO WAS A DEFECT.
%% Register `D.5': `create_cfc_feedforward/5' draws a per-neuron `tau' from the
%% process-global generator and `set_weights/2' leaves it alone, so a genome
%% built twice produced two different controllers. The benchmark was not
%% reproducible, a champion could not be rebuilt from its own genome, and a
%% genome sent to another island would have flown a different drone there.
-spec from_genome(drone_genome:genome()) -> term().
from_genome({Layers, Genes}) ->
    {In, Hidden, Out} = shape(Layers),
    {Weights, Taus} = drone_genome:split(Layers, Genes),
    Net = network_evaluator:create_cfc_feedforward(In, Hidden, Out, tanh, undefined),
    Weighted = network_evaluator:set_weights(Net, drone_genome:dequantize(Weights)),
    network_evaluator:set_neuron_meta(Weighted, meta(Hidden, Out, Taus)).

%% One entry per neuron per layer, hidden layers recurrent and the output layer
%% not. The shape mirrors what `get_neuron_meta/1' returns, because anything else
%% is silently ignored.
meta(Hidden, Out, Taus) -> layers(Hidden, Taus) ++ [[standard() || _ <- lists:seq(1, Out)]].

layers([], _Taus) -> [];
layers([Width | Rest], Taus) ->
    {Mine, Left} = lists:split(Width, Taus),
    [[cfc(T) || T <- Mine] | layers(Rest, Left)].

cfc(Q) -> #{neuron_type => cfc, tau => drone_genome:to_tau(Q), state_bound => 1.0}.

standard() -> #{neuron_type => standard, tau => 1.0, state_bound => 1.0}.

shape(Layers) -> {hd(Layers), lists:sublist(Layers, 2, length(Layers) - 2),
                  lists:last(Layers)}.

%% @doc One tick: perceive, decide, command.
%%
%% ⚠ NOTE WHAT IS ABSENT FROM THE ARGUMENTS. No arena, no munitions, no tick
%% number, no clock. A controller that could see the tick could count, and
%% counting is a way to memorise a fixed start geometry rather than fly.
-spec act(pilot(), #drone{}, [#drone{}], [integer()]) -> {#intent{}, pilot()}.
act(#{net := Net} = P, #drone{} = Self, Others, Comms) ->
    {Out, Stepped} = decide(Net, drone_senses:sense(Self, Others, Comms)),
    {commands(Out), P#{net := Stepped}}.

%% @doc The forward pass, with the CfC state carried out.
%%
%% `evaluate_with_state/2' returns the network with its internal state advanced,
%% which is the whole point of it: the same inputs at two different moments in an
%% engagement do not have to produce the same command.
-spec decide(term(), [float()]) -> {[float()], term()}.
decide(Net, Inputs) -> stepped(network_evaluator:evaluate_with_state(Net, Inputs)).

stepped({Outputs, Net}) -> {Outputs, Net};
stepped(Outputs) when is_list(Outputs) -> {Outputs, undefined}.

%% @doc Ten network outputs to an engine command.
%%
%% ⚠ SCALED HERE AND CLAMPED AGAIN BY THE ENGINE, AND BOTH ARE WANTED. This maps
%% a tanh's range onto the airframe's, so a saturated output means full deflection
%% rather than an arbitrary number; the engine clamps independently because it
%% must not trust a caller at all, and a genome from a stranger reaches it through
%% this same function.
-spec commands([float()]) -> #intent{}.
commands([F, L, V, Y, R, La | Comms]) ->
    #{max_accel := A, max_yaw_rate := Rate, signal_max := Max} = airspace:limits(),
    #intent{thrust_fwd = round(F * A),
            thrust_lat = round(L * A),
            thrust_vert = round(V * A),
            yaw_rate = round(Y * Rate),
            release = trigger(R),
            launch = trigger(La),
            %% ⚠ THE LAST FOUR OUTPUTS WERE DISCARDED UNTIL ITEM 6 AND ARE NOT
            %% ANY MORE. Nothing here interprets them: they are scaled onto the
            %% channel's range and transmitted verbatim, and what they MEAN is
            %% decoded afterwards by correlating them against the rest of a
            %% frame. Charter rule 8 is at its sharpest here, because a named
            %% channel would have been the most natural thing in the world.
            signal = [round(C * Max) || C <- Comms]};
%% A short vector is a null command rather than a crash, because the alternative
%% is a host taken down by a genome it accepted. `drone_genome:validate/1' is what
%% is supposed to make this unreachable, and this clause is what makes the
%% consequence of it being wrong survivable.
commands(_Short) -> #intent{}.

trigger(V) when V > ?FIRE_ABOVE -> 1;
trigger(_V) -> 0.
