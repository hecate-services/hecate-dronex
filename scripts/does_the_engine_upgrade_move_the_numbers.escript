#!/usr/bin/env escript
%%! -sname dronex_engine_diff
%%
%% Does changing the faber_tweann version change what a champion computes?
%%
%% THIS EXISTS SO A FLEET UPGRADE CAN BE DECIDED ON MEASUREMENT RATHER THAN ON A
%% CHANGELOG. dronex jumped faber_tweann 2.0.1 (2026-07-20) to 2.4.0, which is
%% three weeks of engine work, not four releases of it. If the forward pass moved,
%% the roster is no longer comparable to itself and the lineage has to be restarted
%% on a new stream the way `$dronex:roster_g2' was on 2026-08-09. If it did not,
%% the upgrade is behaviour-neutral and the roster stands.
%%
%% ⚠ IT TESTS THE FORWARD PASS, NOT THE EXAM, AND THAT IS DELIBERATE. Exam scores
%% run through `drone_pilot:commands/1', which thresholds at zero, so a controller
%% whose outputs all shifted by 1e-9 can score identically on every rung while
%% computing a different function. The exam is the LOOSER instrument. Bit-equal
%% outputs imply equal exam scores; equal exam scores imply nothing.
%%
%% ⚠⚠ THE INPUT SEQUENCE IS CLOSED-FORM, NOT DRAWN. `rand' would make the trace a
%% function of the generator's version as well as the engine's, and then a
%% difference could not be attributed. Nothing here draws anything.
%%
%% ⚠⚠⚠ IT REPORTS WHICH IMPLEMENTATION PRODUCED THE DIGEST. The native and pure
%% Erlang paths computed a DIFFERENT CfC function until 2.4.0, so a digest that
%% does not name its implementation cannot be compared with another one. The live
%% fleet was measured on 2026-08-10 as `faber_nn_nifs' on all five islands.
%%
%% ⚠⚠⚠⚠ AND IT CARRIES ITS OWN INJECTION TEST, because a digest that never moves
%% is indistinguishable from an instrument that cannot move. Ask it for the
%% `fallback' implementation, whose CfC math is KNOWN to have changed across this
%% upgrade, and the digest must differ between the two versions. If it does not,
%% the script is measuring something other than what it claims and its agreement
%% on the native path means nothing.
%%
%% Usage:
%%   ERL_LIBS=_build/default/lib scripts/does_the_engine_upgrade_move_the_numbers.escript
%%   ERL_LIBS=_build/default/lib scripts/does_the_engine_upgrade_move_the_numbers.escript 500
%%   ERL_LIBS=_build/default/lib scripts/does_the_engine_upgrade_move_the_numbers.escript 200 fallback
%%   ERL_LIBS=_build/default/lib scripts/does_the_engine_upgrade_move_the_numbers.escript 200 both
%%
%% Run it BEFORE the upgrade, keep the output, run it after, diff the two.
%%
%% `both' answers a DIFFERENT question and needs a different instrument. Across
%% two implementations an exact digest is too strict to mean anything: Rust and
%% libm disagree in the last place on tanh alone, so a bit difference is expected
%% and tells you nothing. It reports the largest absolute divergence instead, and
%% the size of that number is the whole answer. Around 1e-16 is two spellings of
%% one function. Around 1e-2 is two functions.

%% Enough ticks for the CfC state to be doing the work rather than the first
%% transient. A tau difference that only shows after a hundred steps is exactly
%% the kind this has to catch.
-define(TICKS, 200).

main([_Ticks, "both" | _] = Args) ->
    divergence(ticks(Args));
main(Args) ->
    Ticks = ticks(Args),
    %% ⚠ BEFORE ANY OTHER tweann_nif CALL. The implementation is chosen lazily on
    %% first use and then cached in persistent_term, so a selection made after
    %% impl/0 has run is silently ignored and the run reports the default.
    ok = choose(Args),
    io:format("~nWhat does the engine compute, exactly?~n~n"),
    io:format("  faber_tweann : ~s~n", [vsn()]),
    io:format("  implementation: ~p~n", [tweann_nif:impl()]),
    io:format("  ticks        : ~p~n", [Ticks]),
    io:format("  inputs       : ~p channels, closed-form~n~n", [drone_senses:channels()]),
    Digests = [report(Name, G, Ticks) || {Name, G} <- champions()],
    fleet(Digests),
    ok.

ticks([T | _]) -> list_to_integer(T);
ticks([]) -> ?TICKS.

%% `native' is the fleet's path and the default. `fallback' exists for the
%% injection test and must never be the basis of a fleet decision, because the
%% two paths were not computing the same function before 2.4.0.
choose([_Ticks, "fallback" | _]) -> selected(fallback);
choose([_Ticks, "native" | _]) -> selected(nif);
choose([_Ticks, "both" | _]) -> ok;
choose([_Ticks, Other | _]) -> halt_with("unknown implementation " ++ Other);
choose(_Args) -> ok.

selected(Impl) ->
    _ = application:load(faber_tweann),
    application:set_env(faber_tweann, nif_impl, Impl).

%% ============================================================================
%% Are the two implementations one function?
%% ============================================================================

divergence(Ticks) ->
    io:format("~nHow far apart are the native and Erlang implementations?~n~n"),
    io:format("  faber_tweann : ~s~n", [vsn()]),
    io:format("  ticks        : ~p~n~n", [Ticks]),
    Cs = champions(),
    Native = traces(nif, Cs, Ticks),
    Fallback = traces(fallback, Cs, Ticks),
    Gaps = [{N, gap(A, B)} || {{N, A}, {_N, B}} <- lists:zip(Native, Fallback)],
    [io:format("  ~-8s max |native - fallback| = ~g~n", [N, G]) || {N, G} <- Gaps],
    io:format("~n  WORST ~g~n~n", [lists:max([G || {_N, G} <- Gaps])]),
    io:format("  Last-place disagreement between Rust and libm is expected and~n"
              "  is around 1e-16. Anything larger is two definitions, not two~n"
              "  spellings, and the roster is only portable across the pair if~n"
              "  this number is noise.~n~n").

%% ⚠ IT REACHES INTO tweann_nif's PRIVATE CACHE, and there is no other way. The
%% implementation is resolved once per VM and held in persistent_term, so a
%% single process cannot otherwise see both. Erasing the key is safe here because
%% nothing else in this escript holds a compiled network across the switch.
traces(Impl, Champions, Ticks) ->
    _ = application:load(faber_tweann),
    application:set_env(faber_tweann, nif_impl, Impl),
    _ = persistent_term:erase({tweann_nif, impl_module}),
    Impl =:= nif orelse tweann_nif:impl() =:= tweann_nif_fallback
        orelse halt_with("could not select the fallback implementation"),
    [{Name, fly(net(G), Ticks, 1, [])} || {Name, G} <- Champions].

net(Genome) ->
    {ok, #{net := Net}} = drone_pilot:init(Genome),
    Net.

gap(TraceA, TraceB) ->
    lists:max([abs(A - B)
               || {TickA, TickB} <- lists:zip(TraceA, TraceB),
                  {A, B} <- lists:zip(TickA, TickB)]).

vsn() ->
    _ = application:load(faber_tweann),
    named(application:get_key(faber_tweann, vsn)).

named({ok, V}) -> V;
named(undefined) -> "UNKNOWN (app not loaded, so this digest names no version)".

%% ⚠ A MISSING CHAMPION DIRECTORY IS A LOUD FAILURE HERE, not an empty list.
%% `what_does_the_ladder_look_like' can honestly run against nothing because it
%% also carries random controllers. This script compares an engine against
%% itself, so zero champions would print a clean page saying nothing at all.
champions() ->
    Dir = "champions",
    {ok, Files} = file:list_dir(Dir),
    B64s = [F || F <- lists:sort(Files), lists:suffix(".b64", F)],
    [] =:= B64s andalso halt_with("no .b64 champions in " ++ Dir),
    [champion(Dir, F) || F <- B64s].

champion(Dir, File) ->
    {ok, B64} = file:read_file(filename:join(Dir, File)),
    {ok, Genome} = drone_genome:unpack(base64:decode(string:trim(B64))),
    {filename:basename(File, ".b64"), Genome}.

halt_with(Why) ->
    io:format("~n  ABORT: ~s~n~n", [Why]),
    halt(1).

report(Name, Genome, Ticks) ->
    {ok, Pilot} = drone_pilot:init(Genome),
    #{net := Net} = Pilot,
    Trace = fly(Net, Ticks, 1, []),
    Digest = digest(Trace),
    io:format("  ~-8s ~s~n", [Name, Digest]),
    io:format("           first ~s~n", [exactly(hd(Trace))]),
    io:format("           last  ~s~n~n", [exactly(lists:last(Trace))]),
    {Name, Digest}.

%% The state is threaded, which is the whole point: tick N sees what tick N-1 did
%% to the CfC state, so a discarded tau shows up as drift rather than as nothing.
fly(_Net, Ticks, N, Acc) when N > Ticks -> lists:reverse(Acc);
fly(Net, Ticks, N, Acc) ->
    {Out, Stepped} = drone_pilot:decide(Net, inputs(N)),
    fly(Stepped, Ticks, N + 1, [Out | Acc]).

%% Closed-form and bounded in [-1, 1], the range `drone_senses' produces. The
%% two incommensurable frequencies keep the sequence from repeating inside the
%% run, so a network cannot sit in one corner of its state space for 200 ticks.
inputs(N) ->
    C = drone_senses:channels(),
    [math:sin(N * 0.37 + I * 0.11) * math:cos(N * 0.013 + I * 0.29)
     || I <- lists:seq(1, C)].

%% term_to_binary of a float list is its IEEE754 bits, so this is exact. A
%% tolerance would be the wrong instrument here: any difference at all means the
%% engine computes a different function, and the question is whether it does, not
%% whether it does so by much.
digest(Trace) ->
    <<D:8/binary, _/binary>> = crypto:hash(sha256, term_to_binary(Trace)),
    string:uppercase(binary:encode_hex(D)).

%% Shortest round-trip representation, so two different doubles never print the
%% same and a printed value can be pasted back in.
exactly(Floats) ->
    lists:flatten(io_lib:format("~w", [[F || F <- Floats]])).

fleet(Digests) ->
    Fleet = digest([D || {_N, D} <- Digests]),
    io:format("  FLEET DIGEST ~s~n~n", [Fleet]),
    io:format("  Same digest before and after an upgrade means the roster stays~n"
              "  comparable and no new stream is needed. A different one is a~n"
              "  physics change and needs a new lineage.~n~n").
