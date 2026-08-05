%% @doc A bout on the wire.
-module(dronex_bout_tests).

-include_lib("eunit/include/eunit.hrl").
-include("airspace.hrl").

topology() ->
    {In, H, Out} = drone_genome:topology(),
    [In] ++ H ++ [Out].

null_genome() ->
    {topology(), lists:duplicate(drone_genome:gene_count(topology()), 0)}.

recorded() ->
    {ok, Mine} = engagement:controller(null_genome()),
    {ok, Theirs} = engagement:controller(chaser),
    Placed = drone_starts:place(1, 1, 2),
    [{A, _, _, _, _, _}, {D, _, _, _, _, _}] = Placed,
    Res = engagement:run(airspace:new(Placed), #{A => Mine, D => Theirs},
                         #{frames => true}),
    Meta = #{kind => training, bout => 1, start_index => 2,
             entrants => [<<"mine">>, <<"chaser">>]},
    {Res, dronex_bout:encode(Meta, Res, maps:get(frames, Res), airspace:limits())}.

%%==============================================================================
%% The shape
%%==============================================================================

%% ⚠ NAMES TRAVEL WITH THE VECTORS. Each frame is a flat integer list with a
%% fixed stride, and a reader must never have to mirror that layout in its own
%% source: a sibling shipped positional lists, appended a field, and the reader's
%% mirror did not follow while the earlier indexes went on decoding correctly.
the_field_names_travel_with_the_frames_test() ->
    {_Res, F} = recorded(),
    ?assertEqual([drone, x, y, z, yaw, health, state], maps:get(frame_fields, F)),
    ?assertEqual([drone, x, y, z, guided], maps:get(munition_fields, F)),
    ?assertEqual(dronex_bout:stride(), length(maps:get(frame_fields, F))),
    ?assertEqual(dronex_bout:munition_stride(), length(maps:get(munition_fields, F))).

%% ⚠ ATOM KEYS, NO TUPLES AS VALUES. An atom key and a binary key of the same
%% name collide into one on the wire, and a tuple does not survive the encoder
%% cleanly. Walked rather than trusted, one level into the frames.
the_wire_rules_hold_test() ->
    {_Res, F} = recorded(),
    maps:foreach(fun (K, V) -> ?assert(is_atom(K)), ?assertNot(is_tuple(V)) end, F),
    [maps:foreach(fun (K, V) -> ?assert(is_atom(K)), ?assertNot(is_tuple(V)) end, Fr)
     || Fr <- maps:get(frames, F)].

every_frame_row_is_a_whole_number_of_drones_test() ->
    {_Res, F} = recorded(),
    [begin
         ?assertEqual(0, length(maps:get(d, Fr)) rem dronex_bout:stride()),
         ?assertEqual(0, length(maps:get(m, Fr)) rem dronex_bout:munition_stride())
     end || Fr <- maps:get(frames, F)].

%%==============================================================================
%% What it says
%%==============================================================================

%% ⚠ IT IS A TRAINING BOUT AND THE FACT SAYS SO. Nothing has crossed the mesh
%% yet: this is the island's own controller against its own drill. Calling it a
%% raid on a page would be the first lie this track told, and the `kind' field is
%% what makes that impossible by accident rather than merely discouraged.
a_bout_declares_that_it_is_not_a_raid_test() ->
    {_Res, F} = recorded(),
    ?assertEqual(training, maps:get(kind, F)),
    ?assertEqual(2, length(maps:get(entrants, F))).

the_outcome_travels_with_the_frames_test() ->
    {Res, F} = recorded(),
    ?assertEqual(maps:get(winner, Res), maps:get(winner, F)),
    ?assertEqual(maps:get(ticks, Res), maps:get(ticks, F)).

%% The arena's own dimensions go too, in the same units the frames use, so a
%% viewer scales to the world rather than to whatever it happened to receive.
the_arena_travels_in_the_frames_own_units_test() ->
    {_Res, F} = recorded(),
    ?assertEqual([1000, 1000, 300], maps:get(arena, F)).

%% ⚠ A WITHDRAWN DRONE IS ALIVE AND OUT OF THE FIGHT, which is not the same as
%% dead. A two-valued state would draw a successful retreat as a casualty.
the_drone_state_is_three_valued_test() ->
    A0 = airspace:new([{{attacker, 1}, attacker, 500 * 20480, 500 * 20480, 100 * 20480, 0},
                       {{defender, 1}, defender, 520 * 20480, 500 * 20480, 100 * 20480, 0}]),
    Mixed = A0#arena{drones = [mark(D) || D <- airspace:drones(A0)]},
    States = [lists:nth(7, Row) || Row <- rows(dronex_bout:frame(Mixed))],
    ?assertEqual([2, 1], States).

mark(#drone{side = attacker} = D) -> D#drone{dead = true};
mark(#drone{} = D) -> D#drone{withdrawn = true}.

rows(#{d := Flat}) -> chunk(Flat, dronex_bout:stride()).

chunk([], _N) -> [];
chunk(L, N) -> {H, T} = lists:split(N, L), [H | chunk(T, N)].

%%==============================================================================
%% Size
%%==============================================================================

%% ⚠ ONE FRAME EVERY SECOND TICK. It halves what a bout weighs and 10 Hz is
%% already smoother than a browser will reliably paint. Asserted because the
%% decimation is invisible in the output: every frame carries its own tick, so a
%% reader cannot tell a decimated bout from a short one without this.
frames_are_decimated_test() ->
    {Res, F} = recorded(),
    Kept = length(maps:get(frames, F)),
    Ran = length(maps:get(frames, Res)),
    ?assertEqual(2, dronex_bout:every()),
    ?assertEqual((Ran + 1) div 2, Kept),
    Ticks = [maps:get(t, Fr) || Fr <- maps:get(frames, F)],
    ?assertEqual(lists:sort(Ticks), Ticks).

%% ⚠ THE MEASUREMENT THAT MAKES A RECORDING VIABLE AT ALL. macula's QUIC path
%% caps a frame at 1 MiB. A bout has to fit with room, or publishing one becomes
%% a chunking problem and the whole "publish it, do not regenerate it" argument
%% collapses.
a_bout_fits_the_transport_with_room_test() ->
    {_Res, F} = recorded(),
    ?assert(byte_size(term_to_binary(F)) < 1048576 div 4).

%% And a full-length one still does. The cap is 1 MiB; a 1200-tick bout at this
%% rate is about 70 KB.
a_full_length_bout_would_still_fit_test() ->
    {_Res, F} = recorded(),
    Per = byte_size(term_to_binary(F)) div max(1, length(maps:get(frames, F))),
    Full = Per * (airspace:max_ticks() div dronex_bout:every()),
    ?assert(Full < 1048576).

%%==============================================================================
%% The topic
%%==============================================================================

%% Its own topic, so a statistics reader is not made to take tens of kilobytes of
%% frames to get a count.
the_bout_has_its_own_topic_test() ->
    Was = os:getenv("HECATE_DRONEX_NS"),
    true = os:unsetenv("HECATE_DRONEX_NS"),
    ?assertEqual(<<"dronex/bout">>, dronex_facts:topic(bout)),
    ?assertNotEqual(dronex_facts:topic(vitals), dronex_facts:topic(bout)),
    ?assert(lists:member(dronex_facts:topic(bout), dronex_facts:topics())),
    restore("HECATE_DRONEX_NS", Was).

%% ⚠ AND THE IDENTITY SPEC ASKS FOR IT. Authority in two places is authority that
%% drifts: publishing to a topic the spec does not name is a call the realm would
%% refuse once delegation lands, and a sibling drifted exactly that way.
the_identity_spec_covers_the_new_topic_test() ->
    #{resources := Asked} = hecate_dronex_service:identity_spec(),
    ?assert(lists:member(dronex_facts:topic(bout), Asked)).

restore(Name, false) -> os:unsetenv(Name), ok;
restore(Name, Value) -> os:putenv(Name, Value), ok.
