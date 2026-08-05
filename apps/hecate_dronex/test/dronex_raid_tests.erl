%% @doc What a raid refuses, and why each refusal exists.
-module(dronex_raid_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CAP, 16).

genome() ->
    {G, _S} = breed:random(rand:seed_s(exsss, {5, 5, 5})),
    G.

sortie(G) -> #{id => drone_genome:id(G), genome => drone_genome:pack(G)}.

request(Sorties) -> dronex_raid:request(<<"attacker-id">>, <<"raid-1">>, Sorties, 42).

%%==============================================================================
%% The fingerprint
%%==============================================================================

the_fingerprint_is_stable_and_32_bytes_test() ->
    ?assertEqual(32, byte_size(dronex_raid:fingerprint())),
    ?assertEqual(dronex_raid:fingerprint(), dronex_raid:fingerprint()).

%% ⚠ `REFUSED' ON ITS OWN IS USELESS. Two islands that cannot fight need to know
%% WHICH of physics, genome shape, senses or runtime differs, and a hash cannot
%% say. These are the parts an operator reads after a refusal.
the_parts_name_everything_that_could_silently_change_an_outcome_test() ->
    P = dronex_raid:fingerprint_parts(),
    ?assertEqual(lists:sort([arch, comms, erts, genes, otp, physics, senses, topology]),
                 lists:sort(maps:keys(P))),
    %% The physics are the whole limits map, not a chosen subset: CHARTER.md
    %% rule 2 says physics ship with the image, so ANY constant differing must
    %% make two images unable to fight.
    ?assertEqual(airspace:limits(), maps:get(physics, P)),
    %% A run is only a pure function of its seed within one OTP release.
    ?assert(byte_size(maps:get(otp, P)) > 0),
    ?assert(byte_size(maps:get(arch, P)) > 0).

%% And the fingerprint actually depends on those parts: change one and it moves.
the_fingerprint_moves_when_a_part_does_test() ->
    P = dronex_raid:fingerprint_parts(),
    Real = crypto:hash(sha256, term_to_binary(P, [deterministic])),
    Drifted = crypto:hash(sha256, term_to_binary(P#{otp => <<"27">>}, [deterministic])),
    ?assertEqual(Real, dronex_raid:fingerprint()),
    ?assertNotEqual(Real, Drifted).

%%==============================================================================
%% What a defender refuses
%%==============================================================================

a_well_formed_raid_is_accepted_test() ->
    ?assertEqual(ok, dronex_raid:validate_request(request([sortie(genome())]), ?CAP)).

a_protocol_mismatch_is_reported_before_anything_else_test() ->
    R = (request([sortie(genome())]))#{protocol := 99},
    ?assertMatch({error, {protocol_mismatch, 99, _}}, dronex_raid:validate_request(R, ?CAP)).

%% ⚠ THE ONE THAT MATTERS MOST, because a mismatched engine does not crash: it
%% produces a plausible fight that is comparable to nothing. A sibling shipped
%% exactly that with the site on one engine commit and the service on another.
an_engine_mismatch_refuses_test() ->
    R = (request([sortie(genome())]))#{fingerprint := crypto:hash(sha256, <<"other build">>)},
    ?assertMatch({error, {engine_mismatch, _, _}}, dronex_raid:validate_request(R, ?CAP)).

a_missing_fingerprint_is_not_a_pass_test() ->
    R = maps:remove(fingerprint, request([sortie(genome())])),
    ?assertEqual({error, no_fingerprint}, dronex_raid:validate_request(R, ?CAP)).

%%==============================================================================
%% The genomes, which is the only per-entrant check
%%==============================================================================

%% ⚠ THE WHOLE RAID REFUSES ON ONE BAD GENOME. A wrong-width genome is padded in
%% silence by the evaluator and a short output falls back to a null command, so
%% the alternative is one entrant flying badly inside a result that looks real.
one_bad_genome_refuses_the_whole_raid_test() ->
    Good = sortie(genome()),
    Bad = #{id => <<"whatever">>, genome => <<"not a genome">>},
    ?assertMatch({error, {unpackable, 1, _}},
                 dronex_raid:validate_request(request([Good, Bad]), ?CAP)),
    %% And the index is the second entrant, not the first: a refusal that cannot
    %% say which one sends the sender through all of them.
    ?assertMatch({error, {unpackable, 0, _}},
                 dronex_raid:validate_request(request([Bad, Good]), ?CAP)).

%% ⚠ AN ID IS THE HASH OF THE PACKED GENOME, which is why the packed form travels
%% rather than a term. If a sender could name a genome anything, the defender's
%% opponent set and the raid record would disagree about what flew.
a_genome_may_not_be_called_something_it_is_not_test() ->
    S = (sortie(genome()))#{id := <<"a name I chose">>},
    ?assertMatch({error, {id_mismatch, 0, <<"a name I chose">>, _}},
                 dronex_raid:validate_request(request([S]), ?CAP)).

%% Somebody else's for loop must not run here.
an_oversized_or_empty_sortie_refuses_test() ->
    G = sortie(genome()),
    ?assertEqual({error, empty_sortie}, dronex_raid:validate_request(request([]), ?CAP)),
    Many = lists:duplicate(?CAP + 1, G),
    ?assertMatch({error, {sortie_too_large, _, ?CAP}},
                 dronex_raid:validate_request(request(Many), ?CAP)).

%%==============================================================================
%% Shape
%%==============================================================================

a_request_survives_a_round_trip_test() ->
    R = request([sortie(genome())]),
    ?assertMatch({ok, _}, dronex_raid:decode_request(R)),
    ?assertEqual({error, malformed_request}, dronex_raid:decode_request(#{})),
    ?assertEqual({error, malformed_request}, dronex_raid:decode_request(not_a_map)).

%% ⚠ THE CALL IS A HANDSHAKE AND CARRIES NO OUTCOME. It used to return the winner
%% and every genome's fate, which meant the caller was blocked for a whole
%% engagement and the timeout had to cover the callee's real work. What it is
%% still for is ADMISSION CONTROL: two attackers both see an island open, both
%% muster, both send, and only a synchronous answer can turn one away before it
%% has committed a party.
an_acceptance_survives_a_round_trip_test() ->
    Reply = dronex_raid:accepted(<<"raid-1">>),
    ?assertMatch({ok, _}, dronex_raid:decode_reply(Reply)),
    ?assertEqual(<<"raid-1">>, maps:get(raid_id, Reply)),
    %% The outcome is NOT in here. It arrives later, as a fact.
    ?assertNot(maps:is_key(fate, Reply)),
    ?assertNot(maps:is_key(outcome, Reply)),

    ?assertEqual({error, malformed_reply}, dronex_raid:decode_reply(#{})),
    %% An error from the transport passes through as itself rather than being
    %% relabelled: `no_healthy_station' must not become `malformed_reply'.
    ?assertEqual({error, timeout}, dronex_raid:decode_reply({error, timeout})),
    Old = Reply#{protocol := 0},
    ?assertMatch({error, {protocol_mismatch, 0, _}}, dronex_raid:decode_reply(Old)).

%% ⚠ ADDRESSED TO AN ISLAND, BECAUSE THERE IS NO DIRECTORY. An attacker learns an
%% island_id from the public realm, which is the only place islands become
%% visible to each other, and calls it on the FLEET realm — which is why a
%% stranger holding the public tag cannot start a fight.
a_raid_is_addressed_to_one_island_test() ->
    ?assertEqual(<<"dronex.raid.abc">>, dronex_raid:procedure(<<"abc">>)),
    ?assertNotEqual(dronex_raid:procedure(<<"a">>), dronex_raid:procedure(<<"b">>)).

%%==============================================================================
%% The settlement, which is a fact rather than a return value
%%==============================================================================

%% ⚠ SMALL, AND SEPARATE FROM THE RECORDING BECAUSE OF WHAT THE RECORDING WEIGHS.
%% `dronex/raid' carries frames — of the order of 150 KB. An attacker needs six
%% genome fates to put its survivors back, which is a few hundred bytes. Settling
%% off the public recording would make every island in the archipelago download
%% every fight to learn the outcome of its own.
a_settlement_carries_only_what_settles_a_roster_test() ->
    Fact = with_data_dir(fun () ->
        dronex_facts:settled(<<"r1">>, defender, [{<<"g1">>, survived}, {<<"g2">>, lost}])
    end),
    ?assertEqual(lists:sort([fact_version, fate, island, island_id, outcome, raid_id]),
                 lists:sort(maps:keys(Fact))),
    ?assertEqual(<<"r1">>, maps:get(raid_id, Fact)),
    ?assertEqual(defender, maps:get(outcome, Fact)),
    ?assertEqual([#{id => <<"g1">>, fate => survived},
                  #{id => <<"g2">>, fate => lost}], maps:get(fate, Fact)),
    %% No frames. That is the whole point of it being its own fact.
    ?assertNot(maps:is_key(frames, Fact)).

with_data_dir(F) ->
    Dir = "/tmp/dronex_raid_tests_" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(Dir ++ "/x"),
    true = os:putenv("HECATE_DRONEX_DATA_DIR", Dir),
    try F() after os:unsetenv("HECATE_DRONEX_DATA_DIR") end.

%%==============================================================================
%% ⚠ TWO WITNESSES TO ONE RAID
%%==============================================================================
%%
%% Until this existed the record was one-sided: only the defender published, so a
%% defender that went dark after accepting left the attacker six airframes poorer
%% with nothing anywhere recording that the raid had happened.
both_sides_witness_the_same_raid_from_their_own_side_test() ->
    Att = with_data_dir(fun () ->
        dronex_facts:committed(<<"r1">>, attacker, {<<"them">>, 6}) end),
    Def = with_data_dir(fun () ->
        dronex_facts:committed(<<"r1">>, defender, {<<"us">>, 6}) end),

    %% Same raid, different claims, neither authoritative over the other.
    ?assertEqual(<<"r1">>, maps:get(raid_id, Att)),
    ?assertEqual(<<"r1">>, maps:get(raid_id, Def)),
    ?assertEqual(attacker, maps:get(role, Att)),
    ?assertEqual(defender, maps:get(role, Def)),
    ?assertEqual(<<"them">>, maps:get(opponent_id, Att)),
    ?assertEqual(6, maps:get(airframes, Att)),

    ?assertEqual(lists:sort([airframes, fact_version, island, island_id,
                             opponent_id, raid_id, role]),
                 lists:sort(maps:keys(Att))).

%% It is public, unlike the settlement: the settlement is addressed and must stay
%% small, while a commitment exists to be a record and to be drawn.
a_commitment_is_something_a_spectator_may_see_test() ->
    ?assert(lists:member(dronex_facts:topic(committed), dronex_facts:topics())),
    #{resources := Asked} = hecate_dronex_service:identity_spec(),
    ?assert(lists:member(dronex_facts:topic(committed), Asked)),
    ?assertNotEqual(dronex_facts:topic(committed), dronex_facts:topic(settled)).

%%==============================================================================
%% ⚠ THE FINGERPRINT MUST BE THE SAME ON TWO MACHINES OR IT IDENTIFIES NOTHING
%%==============================================================================

%% `term_to_binary/1' does not encode a map canonically. For a map large enough
%% to be a hashmap — `airspace:limits/0' has about thirty-five keys — entries are
%% emitted in internal hash order, and for atom keys that order depends on the
%% node's atom table. Two islands on the identical image produced different
%% fingerprints and filtered each other out as incompatible engines, so no raid
%% was ever attempted and nothing reported an error.
%%
%% This pins the encoding. It goes red the moment the flag is dropped, because
%% plain and deterministic differ even on one node.
the_fingerprint_uses_a_canonical_encoding_test() ->
    Parts = dronex_raid:fingerprint_parts(),
    ?assertEqual(crypto:hash(sha256, term_to_binary(Parts, [deterministic])),
                 dronex_raid:fingerprint()),
    %% And the two encodings really are different, so the assertion above has
    %% something to catch rather than being true either way.
    ?assertNotEqual(term_to_binary(Parts), term_to_binary(Parts, [deterministic])).

%% The physics map is the one that is big enough for this to bite, so it is worth
%% saying out loud that it is over the threshold rather than assuming.
the_physics_map_is_large_enough_to_be_a_hashmap_test() ->
    ?assert(maps:size(airspace:limits()) > 32).
