%% @doc The boundary with faber_tweann, asserted rather than described.
%%
%% design/DESIGN_WHAT_WE_TAKE_FROM_FABER.md draws a line: the inference and
%% serialization surface of `network_evaluator', plus `network_onnx', and nothing
%% else. This is that line, in a form that goes red when it moves.
%%
%% ⚠ AND IT EXISTS BECAUSE THE SURVEY BEHIND THAT DOCUMENT WAS GOT WRONG TWICE.
%% Register `INHERITED-7' and `I.1'. A boundary described in prose is a boundary
%% nobody notices crossing.
-module(faber_boundary_tests).

-include_lib("eunit/include/eunit.hrl").

%% The dependency is in rebar.config at the spine rather than at the first module
%% that needs it, because it carries a Rust NIF and a NIF that does not build
%% fails in a container and never on a laptop. This is the assertion that the
%% build actually produced something loadable.
the_library_is_present_test() ->
    ?assertNotEqual(non_existing, code:which(network_evaluator)),
    ?assertNotEqual(non_existing, code:which(network_onnx)).

%% ⚠ THE SEAM AN EVOLUTIONARY OPERATOR NEEDS, and the thing that was declared not
%% to exist. A flat float vector out, a flat float vector in, round-tripping.
%% Everything the trainer will do at item 5 stands on exactly this.
the_genome_is_a_flat_vector_test() ->
    Net = network_evaluator:create_feedforward(41, [24], 9),
    Weights = network_evaluator:get_weights(Net),
    ?assert(is_list(Weights)),
    ?assert(lists:all(fun erlang:is_float/1, Weights)),
    %% 24 x (41 + 1) + 9 x (24 + 1), the shape in design/DESIGN_THE_DRONE.md.
    ?assertEqual(24 * 42 + 9 * 25, length(Weights)),
    Zeroed = [0.0 || _ <- Weights],
    Set = network_evaluator:set_weights(Net, Zeroed),
    ?assertEqual(Zeroed, network_evaluator:get_weights(Set)).

%% The controller contract from design/DESIGN_THE_DRONE.md: 41 channels in, 9
%% out. Asserted here so that changing the channel list without changing the
%% design document breaks something.
the_controller_shape_evaluates_test() ->
    Net = network_evaluator:create_feedforward(41, [24], 9),
    Out = network_evaluator:evaluate(Net, lists:duplicate(41, 0.0)),
    ?assertEqual(9, length(Out)).

%% ⚠ NOTHING HERE TOUCHES MNESIA OR THE GENOTYPE PATH. faber_tweann lists mnesia
%% because its DXNN genotype path uses it; the `network_evaluator' path does not,
%% and this repository never calls `genotype:init_db/0'. A stray call would
%% create tables in a fleet node's data directory and nobody would find out until
%% disk usage moved.
%%
%% ⚠⚠ STATIC RATHER THAN RUNTIME, AND THE FIRST VERSION OF THIS TEST WAS BOTH
%% WRONG AND USELESS. It asked a live mnesia for its table list, which under
%% eunit is not running at all, so it failed with `node_not_running' and told
%% nobody anything about the boundary. Its assertion was also nonsense:
%% `A -- B ++ C' parses as `A -- (B ++ C)'.
%%
%% Reading the compiled call graph instead answers the question that was actually
%% being asked, works whether or not mnesia is up, and goes red the moment
%% somebody adds the call rather than the moment somebody runs the release.
the_boundary_holds_no_mnesia_and_no_genotype_test() ->
    [?assertEqual({Mod, []}, {Mod, forbidden_calls(Mod)}) || Mod <- our_modules()].

%% Every module this repository compiles, as against everything on the path.
our_modules() ->
    Dir = filename:dirname(code:which(hecate_dronex_service)),
    [list_to_atom(filename:basename(F, ".beam"))
     || F <- filelib:wildcard(filename:join(Dir, "*.beam"))].

forbidden_calls(Mod) ->
    {ok, {Mod, [{imports, Imports}]}} = beam_lib:chunks(code:which(Mod), [imports]),
    [{M, F, A} || {M, F, A} <- Imports, lists:member(M, [mnesia, genotype])].
