%% @doc One engagement, encoded so a spectator can replay it. PURE.
%%
%% THIS EXISTS SO SOMETHING CAN BE WATCHED BEFORE ANYTHING CAN BE RAIDED.
%%
%% ==========================================================================
%% ⚠ IT IS A RECORDING, NOT A STREAM, AND THAT IS THE WHOLE ARCHITECTURE
%% ==========================================================================
%%
%% The island runs the engagement, encodes every frame, and publishes the lot as
%% ONE fact when it is over. A spectator stores it and animates locally, with no
%% server round trip per frame.
%%
%% The alternative, and the one a sibling shipped, is for the site to receive the
%% inputs and RE-RUN the fight. That put a game engine inside a content website,
%% version-locked to one node, with every viewer repeating identical work and a
%% fingerprint that drifted between them. Raf's correction was
%% `beam-campus.net SHOULD NOT REGENERATE, it should AGGREGATE and VISUALIZE',
%% and this module is that correction in a data format.
%%
%% It is also cheaper, and it buys scrub, pause and slow motion, none of which a
%% live feed can offer.
%%
%% ==========================================================================
%% ⚠⚠ THIS IS A TRAINING BOUT AND NOT A RAID, AND THE FACT SAYS SO
%% ==========================================================================
%%
%% Nothing has crossed the mesh yet. What is published here is the island's own
%% best controller against one of its scripted drills, which is what an island
%% actually spends its time doing. Calling it a raid on the page would be the
%% first lie this track told, and the `kind' field is what stops that being
%% possible by accident.
-module(dronex_bout).

-include("airspace.hrl").

-export([encode/4, frame/1, stride/0, munition_stride/0, metres/1, every/0]).

%% Seven integers per drone per frame: which drone, where, which way it is
%% pointing, how hurt it is, and whether it is still in the fight.
-define(STRIDE, 7).
%% Five per munition: whose, where, and whether it steers.
-define(MUNITION_STRIDE, 5).

%% ⚠ ONE FRAME EVERY SECOND TICK: 10 Hz of drawing from 20 Hz of simulation.
%% Nothing in the physics reads this. It is a publishing decision and it lives
%% with the publisher, which is why it is here and not in `engagement'. It halves
%% what a full-length bout weighs, and 10 Hz is already smoother than a browser
%% will reliably paint.
-define(EVERY, 2).

-spec every() -> pos_integer().
every() -> ?EVERY.

-spec stride() -> pos_integer().
stride() -> ?STRIDE.

-spec munition_stride() -> pos_integer().
munition_stride() -> ?MUNITION_STRIDE.

%% @doc Position units to whole metres.
%%
%% ⚠ THE SIMULATION RUNS AT MILLIMETRE RESOLUTION AND NOTHING IS DRAWN AT IT.
%% Quantizing here is what keeps a bout in the tens of kilobytes rather than the
%% hundreds, and a metre is already finer than a pixel at any zoom a viewer will
%% use.
-spec metres(integer()) -> integer().
metres(U) -> U div 20480.

%% @doc The whole bout as one fact.
%%
%% ⚠ THE ENTRANTS' GENOME IDS TRAVEL WITH IT. A spectator cannot check them, but
%% an ISLAND can: the same two ids and the same start index reproduce the fight,
%% which is what makes a published bout evidence rather than an animation. The
%% engine's own limits go too, because two islands running different constants
%% produce results comparable to nothing.
-spec encode(map(), map(), [#arena{}], map()) -> map().
encode(Meta, Result, Frames, Limits) ->
    #{kind => maps:get(kind, Meta, training),
      bout => maps:get(bout, Meta, 0),
      start_index => maps:get(start_index, Meta, 0),
      entrants => maps:get(entrants, Meta, []),
      winner => maps:get(winner, Result, draw),
      ticks => maps:get(ticks, Result, 0),
      %% How much was said during this fight. A recording in which nobody
      %% transmitted is not evidence about coordination, and a spectator that
      %% narrates one as if it were would be reading tea leaves.
      signal_volume => maps:get(signal_volume, Result, 0),
      survivors => [name(Id) || Id <- maps:get(survivors, Result, [])],
      withdrawn => [name(Id) || Id <- maps:get(withdrawn, Result, [])],
      %% Names travel with the vectors, because a reader must never have to
      %% mirror a field order in its own source.
      frame_fields => [drone, x, y, z, yaw, health, state],
      munition_fields => [drone, x, y, z, guided],
      %% ⚠ WHERE THE TOWERS STOOD, AND EMPTY WHEN THERE WERE NONE. A raider
      %% fights over somebody else's ground with no stations of its own, and
      %% that asymmetry is what prices a raid; if it never reaches the wire it
      %% is invisible on the exhibit and readable only in a log, which is the
      %% same as asking an audience to take the interesting part on trust.
      %%
      %% Once per fight rather than once per frame: phase 1 placement does not
      %% move, and repeating five fixed positions across 600 frames would be
      %% three thousand numbers saying one thing.
      ground_fields => [x, y, z],
      %% ⚠ AND HOW FAR EACH ONE REACHES, or a spectator can draw five dots and
      %% not the thing that matters about them: WHERE THE HOLES ARE. The gaps
      %% between coverage and the volume overhead are the whole counterplay to a
      %% network, so a picture without the range is a picture of the towers
      %% rather than a picture of the defence.
      ground_range => metres(maps:get(sensor_range, Limits, 0)),
      ground => lists:append([[metres(X), metres(Y), metres(Z)]
                              || #{x := X, y := Y, z := Z}
                                 <- maps:get(ground, Result, [])]),
      arena => [metres(maps:get(arena_x, Limits)),
                metres(maps:get(arena_y, Limits)),
                metres(maps:get(arena_z, Limits))],
      %% Every second one, and the count of what was DROPPED is not needed
      %% because the tick on each frame says exactly which ones survived.
      frames => [frame(A) || A <- decimated(Frames)]}.

decimated(Frames) ->
    [A || {A, N} <- lists:zip(Frames, lists:seq(0, length(Frames) - 1)),
          N rem ?EVERY =:= 0].

%% @doc One frame: the tick, the drones, and the munitions in flight.
-spec frame(#arena{}) -> map().
frame(#arena{} = A) ->
    #{t => airspace:tick_of(A),
      d => lists:append([drone_row(D) || D <- airspace:drones(A)]),
      m => lists:append([munition_row(M) || M <- airspace:munitions(A)])}.

%% ⚠ `state' IS THREE-VALUED, NOT A BOOLEAN, and the third value is the point.
%% A withdrawn drone is ALIVE and out of the fight, which is a different thing
%% from dead, and a spectator that could not tell them apart would draw a
%% successful retreat as a casualty.
drone_row(#drone{} = D) ->
    [index_of(D#drone.id),
     metres(D#drone.x), metres(D#drone.y), metres(D#drone.z),
     D#drone.yaw,
     health_percent(D),
     state_of(D)].

state_of(#drone{dead = true}) -> 2;
state_of(#drone{withdrawn = true}) -> 1;
state_of(#drone{}) -> 0.

health_percent(#drone{health = H}) -> max(0, H * 100 div 10000).

munition_row(#munition{} = M) ->
    [index_of(M#munition.owner),
     metres(M#munition.x), metres(M#munition.y), metres(M#munition.z),
     guided(M#munition.guided)].

guided(true) -> 1;
guided(false) -> 0.

%% `drone_starts' names entrants `{attacker, K}' and `{defender, K}'. The wire
%% carries a small integer instead: side in the low bit, position above it, so a
%% reader can colour a mark without decoding a tuple. Tuples do not survive the
%% encoder cleanly, which is the wire rule this obeys.
index_of({attacker, K}) -> K * 2;
index_of({defender, K}) -> K * 2 + 1;
index_of(_Other) -> 0.

name({attacker, K}) -> K * 2;
name({defender, K}) -> K * 2 + 1;
name(_Other) -> 0.
