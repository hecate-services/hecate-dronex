%% @doc WHAT AN ISLAND SAYS ABOUT ITSELF, AND WHERE IT SAYS IT. PURE.
%%
%% ONE FACT SO FAR, `dronex/vitals': what exists at this commit and not a field
%% more. Small enough to keep for ever, which is what a statistics reader wants.
%%
%% ⚠ THE DESIGN NAMES A DOZEN MORE FIELDS AND NONE OF THEM IS HERE YET. The
%% benchmark profile, the ablation delta, the sortie counts, the opponent-set
%% composition and the coverage summary all arrive in the same commit as the
%% thing that computes them. A field published before it means anything is a
%% number a reader will chart, and a chart of a constant zero is indistinguishable
%% from a chart of a mechanism that does not work.
%%
%% THE ISLAND ID IS IN THE PAYLOAD AND NEVER IN THE TOPIC. Putting it in the
%% topic is the mistake that scales worst: a thousand islands become a thousand
%% topics, subscription management collapses, and a reader who wants "all
%% islands" cannot ask for it. One topic, an `island_id' field, and a subscriber
%% filters. The namespace separates whole DEPLOYMENTS, not islands.
%%
%% TOTALS RATHER THAN RATES, because a rate is recoverable from two totals and a
%% total is not recoverable from rates. A reader that misses a fact can still work
%% out what happened across the gap.
%%
%% THE TICK IS ON EVERY FACT, and it is not decoration. Publishing runs on wall
%% clock and the island runs on its own pace, so two consecutive facts may be one
%% tick apart or a million. Without the tick a reader cannot tell a stalled island
%% from a slow one.
%%
%% ==========================================================================
%% WIRE RULES, EACH EARNED BY SOMETHING THAT BROKE
%% ==========================================================================
%%
%% Atom keys only, no tuples as values, integers rather than floats. A tuple does
%% not survive the encoder cleanly, and an atom key and a binary key of the same
%% name collide into one: `#{foo => 1, <<"foo">> => 2}' ships two entries and
%% arrives with one.
%%
%% NAMES TRAVEL WITH VECTORS. Nothing here is a vector yet. When the benchmark
%% profile arrives it carries its rung names beside its numbers, because a
%% sibling shipped positional lists, appended a field, and the reader's mirror
%% did not follow: the earlier indexes went on decoding correctly, so nothing
%% looked wrong.
-module(dronex_facts).

-export([topic/1, topics/0, namespace/0, fact_version/0]).
-export([vitals/1, bout/4]).

-define(DEFAULT_NS, <<"dronex">>).

%% ⚠ BUMPED WHENEVER THE SHAPE CHANGES, INCLUDING AN APPEND. A reader has no
%% other way to ask "is the field I want in this frame, or am I talking to an
%% island that predates it".
%%
%% 3 adds `dronex/bout', a whole engagement published as a recording. The vitals
%% shape is unchanged; the version moves because a reader that wants to know
%% whether an island publishes bouts at all has no other way to ask.
%% 2 adds the trainer and the frozen exam: `generation', `rounds', `admissions',
%% and the benchmark profile with its rung names beside it. They arrive together
%% because they arrived together in the code: an island that breeds without
%% publishing what it sat is an island whose numbers cannot be read.
%% 1 was the first fact this track ever published.
-define(FACT_VERSION, 3).

-spec fact_version() -> pos_integer().
fact_version() -> ?FACT_VERSION.

%% Topics are `<namespace>/<leaf>'. The namespace tells one deployment from
%% another, for instance a laptop from the fleet, and is NOT how islands are
%% distinguished.
-spec topic(atom()) -> binary().
topic(vitals) -> leaf(<<"vitals">>);
%% ITS OWN TOPIC, so a reader chooses whether to hear it. Vitals are counts and
%% are small enough to keep forever; a bout is a recording of tens of kilobytes
%% and a statistics reader must not have to take one to get the other.
topic(bout) -> leaf(<<"bout">>).

%% @doc Every topic this island publishes on.
%%
%% ⚠ EXPORTED SO THE SERVICE'S `identity_spec/0' CAN ASK FOR EXACTLY THESE AND NO
%% MORE, and so a test can compare the two. Authority that names a topic nothing
%% publishes to is a credential lying around; publishing to a topic the spec does
%% not name is a call the realm would refuse once delegation lands. A sibling
%% drifted exactly that way.
%%
%% `dronex/raid' and `dronex/roster' are designed and are deliberately absent
%% until something publishes them. `dronex/bout' is here because something does:
%% an island's own best controller against one of its drills, which is what an
%% island actually spends its time doing.
-spec topics() -> [binary()].
topics() -> [topic(vitals), topic(bout)].

leaf(Leaf) -> <<(namespace())/binary, "/", Leaf/binary>>.

-spec namespace() -> binary().
namespace() -> ns(os:getenv("HECATE_DRONEX_NS")).

ns(false) -> ?DEFAULT_NS;
ns("") -> ?DEFAULT_NS;
ns(Str) -> list_to_binary(string:trim(Str)).

%% @doc What this island is, right now.
%%
%% Takes the island rather than reading anything about it, so it stays pure and a
%% test can build one without a running node.
%%
%% `station_*' is the exception and it is read, because the door this island is
%% actually speaking through is a property of the live connection and not of the
%% island. It is merged in rather than passed, so a caller cannot forget it.
-spec vitals(island:island()) -> map().
vitals(Island) ->
    maps:merge(
      #{fact_version => ?FACT_VERSION,
        island => dronex_identity:island(),
        island_id => dronex_identity:island_id(),
        tick => island:tick_of(Island),
        %% Zero at this commit, and published anyway. CHARTER.md rule 4: a
        %% capacity that was never exercised is not evidence of anything, so the
        %% count goes out beside the null from the first fact. An island with an
        %% empty roster and an island that does not report a roster look
        %% identical otherwise.
        roster => island:roster_depth(Island),
        capacity => island:capacity(Island),
        generation => island:generation_of(Island),
        %% ⚠ EXERCISE COUNTS BESIDE EVERY NULL. CHARTER.md rule 4. A trainer that
        %% has proposed nothing and a trainer whose every proposal was rejected
        %% look identical without these, and they are different situations.
        rounds => island:rounds_of(Island),
        admissions => island:admissions_of(Island)},
      maps:merge(station(),
                 maps:merge(frozen(island:benchmark_of(Island)),
                            ablation(island:ablation_of(Island),
                                     island:ablations_of(Island))))).

%% ⚠ THE THREE NUMBERS FROM `DESIGN_DRONES_THAT_TALK.md', AND THE FOURTH THAT
%% MAKES THEM READABLE. Volume, delta and entropy each mean something specific
%% when they are zero, and none of those meanings is available unless the reader
%% can also tell whether the measurement was ever taken. `ablations' is that, and
%% it is why an island that has not ablated publishes zeros with a zero count
%% rather than publishing nothing.
ablation(undefined, Count) ->
    #{signal_volume => 0, signal_entropy => 0, ablation_void => true,
      ablation_delta_air => 0, ablation_delta_ground => 0, ablation_delta_all => 0,
      ablations => Count};
ablation(Report, Count) ->
    #{air := Air, ground := Ground, all := All} = maps:get(delta, Report),
    #{mean := Entropy} = maps:get(entropy, Report),
    %% ⚠ FLAT KEYS RATHER THAN A NESTED MAP. A spectator reads these beside the
    %% benchmark rungs, which are already flat, and a nested map would make the
    %% page's decoder branch on shape for no gain on the wire.
    #{signal_volume => maps:get(volume, Report),
      signal_entropy => Entropy,
      ablation_void => maps:get(void, Report),
      ablation_delta_air => Air,
      ablation_delta_ground => Ground,
      ablation_delta_all => All,
      ablations => Count}.

%% ⚠ THE RUNG NAMES TRAVEL WITH THE NUMBERS. A sibling shipped positional lists,
%% appended a field, and the reader's mirror did not follow: the earlier indexes
%% went on decoding correctly, so nothing looked wrong.
%%
%% ⚠⚠ AND THE PROFILE IS NEVER SUMMED ON THE WIRE ANY MORE THAN IT IS IN MEMORY.
%% There is no `benchmark_score' field and there will not be one: a single number
%% needs weights, and weights are a judgement about which rung matters smuggled
%% into a measurement.
frozen(Profile) ->
    #{benchmark_rungs => maps:get(rungs, Profile, []),
      benchmark_wins => maps:get(wins, Profile, []),
      benchmark_draws => maps:get(draws, Profile, []),
      benchmark_losses => maps:get(losses, Profile, []),
      %% Zero means the exam has not been sat, which a reader must be able to
      %% tell from having sat it and lost everything.
      benchmark_starts => maps:get(starts, Profile, 0)}.

%% A door that cannot be read is reported as unknown rather than omitted. A key
%% that appears only sometimes is a field a chart silently drops.
station() -> described(dronex_mesh:station()).

described({ok, Door}) -> Door;
described({error, _Why}) ->
    #{station_host => <<"unknown">>,
      station_connected => false,
      station_id => <<>>}.

%% @doc A whole engagement, as a recording.
%%
%% ⚠ SEPARATE FROM `vitals/1' BECAUSE THEY ARE DIFFERENT SIZES AND DIFFERENT
%% RATES. Counts are small enough to keep forever and go out every second; a bout
%% is tens of kilobytes and goes out when one happens. Folding them together
%% would make a statistics reader pay for frames it will never draw, and would
%% force both onto one clock.
-spec bout(island:island(), map(), map(), list()) -> map().
bout(Island, Meta, Result, Frames) ->
    maps:merge(
      #{fact_version => ?FACT_VERSION,
        island => dronex_identity:island(),
        island_id => dronex_identity:island_id(),
        tick => island:tick_of(Island)},
      dronex_bout:encode(Meta, Result, Frames, airspace:limits())).
