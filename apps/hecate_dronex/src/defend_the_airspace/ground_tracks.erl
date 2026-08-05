%% @doc Contacts in, confirmed tracks out. PURE and DETERMINISTIC.
%%
%% THIS EXISTS BECAUSE A CONTACT IS NOT A TARGET AND THE DIFFERENCE IS THE WHOLE
%% COUNTER-DRONE PROBLEM.
%%
%% ==========================================================================
%% ⚠ NOTHING HERE PORTED, AND THE DESIGN SAID SO BEFORE IT WAS WRITTEN
%% ==========================================================================
%%
%% The counter-UAS line's `on_contact_observed_correlate_track' looks like the
%% thing to lift and is not. Its own docstring calls itself "the SKELETON
%% minimum", and one line shows why:
%%
%%     TrackId = <<"track-", DroneId/binary>>
%%
%% The correlation is string concatenation on the drone's **self-reported
%% identity**. That works for Remote-ID, where the target announces who it is,
%% and is meaningless for any sensor that does not hand you a name — which is
%% every sensor that matters against something trying not to be found.
%% `maybe_confirm_track` was a one-shot idempotence guard: no threshold, no
%% evidence, no track-lost.
%%
%% So association is by PREDICTED POSITION with a gate, which is the standard
%% answer and the only one available when contacts are anonymous.
%%
%% ==========================================================================
%% ⚠⚠ TERMS IN A FOLD. NO EVENTS, NO COMMANDS, NO STORE, NO MESH
%% ==========================================================================
%%
%% Contacts and tracks inside an engagement are values passed from one tick to
%% the next. Nothing here writes an event or dispatches a command. The retired
%% per-drone aggregate cost one store write per reposition, and that judgement
%% stands: a fight is a fold over 1200 ticks and cannot afford a round trip per
%% observation.
-module(ground_tracks).

-include("airspace.hrl").

-export([empty/0, advance/3, confirmed/1, count/1]).

-export_type([track/0, state/0]).

%% ⚠ STATUS IS BIT FLAGS AND AN INTEGER, which is this codebase's house rule for
%% status fields and is what `evoq_bit_flags' exists for. A track is TENTATIVE
%% while it is accumulating and CONFIRMED once it has crossed the threshold; it
%% keeps the confirmed bit for as long as it lives, because a network that
%% un-confirmed and re-confirmed a target every time a detection was missed would
%% stutter its cueing at exactly the wrong moment.
-define(TENTATIVE, 1).
-define(CONFIRMED, 2).

-type track() :: #{x := integer(), y := integer(), z := integer(),
                   vx := integer(), vy := integer(), vz := integer(),
                   evidence := non_neg_integer(),
                   seen := non_neg_integer(),
                   status := non_neg_integer()}.

-type state() :: [track()].

-spec empty() -> state().
empty() -> [].

-spec count(state()) -> non_neg_integer().
count(Tracks) -> length(Tracks).

%% @doc Every track that has earned the right to be spoken about.
-spec confirmed(state()) -> [track()].
confirmed(Tracks) ->
    %% `has/2' for ONE flag; `has_all/2' takes a list and quietly means something
    %% else when handed an integer.
    [T || #{status := S} = T <- Tracks, evoq_bit_flags:has(S, ?CONFIRMED)].

%%==============================================================================
%% One tick
%%==============================================================================

%% @doc Fold this tick's contacts into the track picture.
%%
%% ⚠ THE ORDER IS ASSOCIATE, THEN AGE, THEN DROP, and it matters. Ageing before
%% association would drop a track on the same tick a contact arrived for it, so a
%% target at the edge of a network — seen, lost, seen — would never accumulate
%% anything and the fringe of the network would be worth nothing at all.
-spec advance(state(), [ground_sensor:contact()], non_neg_integer()) -> state().
advance(Tracks, Contacts, Tick) ->
    Updated = lists:foldl(fun (C, Acc) -> absorb(C, Acc, Tick) end, predicted(Tracks), Contacts),
    [T || #{seen := Seen} = T <- Updated, Tick - Seen =< ?TRACK_DROP_TICKS].

%% Dead reckoning between contacts. A track with a velocity keeps moving while
%% unobserved, which is what makes the gate meaningful: comparing a contact
%% against where a target WAS rather than where it should be by now would lose
%% every fast mover, and a fast mover is the one worth tracking.
predicted(Tracks) ->
    [T#{x := X + Vx, y := Y + Vy, z := Z + Vz}
     || #{x := X, y := Y, z := Z, vx := Vx, vy := Vy, vz := Vz} = T <- Tracks].

absorb(Contact, Tracks, Tick) ->
    matched(nearest(Contact, Tracks), Contact, Tracks, Tick).

%% ⚠ THE NEAREST TRACK INSIDE THE GATE, OR A NEW ONE. Nothing clever: no
%% multi-hypothesis, no assignment problem. Two targets closer together than the
%% gate will merge into one track, and that is a real limitation of a real
%% algorithm rather than a bug — it is also exactly why flying a tight formation
%% through a network is a tactic and not a mistake.
nearest(#{x := Cx, y := Cy, z := Cz}, Tracks) ->
    Scored = [{fixed:mag3(Cx - X, Cy - Y, Cz - Z), T}
              || #{x := X, y := Y, z := Z} = T <- Tracks],
    closest(lists:sort(fun ({A, _}, {B, _}) -> A =< B end, Scored)).

closest([{D, T} | _]) when D =< ?TRACK_GATE -> {ok, T};
closest(_TooFarOrEmpty) -> none.

matched(none, Contact, Tracks, Tick) -> [born(Contact, Tick) | Tracks];
matched({ok, T}, Contact, Tracks, Tick) -> [fed(T, Contact, Tick) | Tracks -- [T]].

%% A first contact is a track with no velocity and one piece of evidence. It is
%% TENTATIVE: the network has seen something once, which against a network that
%% invents ghosts is not yet worth saying out loud.
born(#{x := X, y := Y, z := Z}, Tick) ->
    #{x => X, y => Y, z => Z, vx => 0, vy => 0, vz => 0,
      evidence => 1, seen => Tick, status => ?TENTATIVE}.

%% ⚠ THE POSITION IS SMOOTHED, NOT REPLACED. A raw contact carries tens of metres
%% of noise at range, so jumping the track to it would make a confirmed track
%% jitter as badly as the sensor does, and the cue the network broadcasts would
%% be noise with a threshold in front of it. Half-way is the cheapest filter that
%% is honestly a filter.
fed(#{x := X, y := Y, z := Z, evidence := E, status := S} = T,
    #{x := Cx, y := Cy, z := Cz}, Tick) ->
    Nx = (X + Cx) div 2,
    Ny = (Y + Cy) div 2,
    Nz = (Z + Cz) div 2,
    T#{x := Nx, y := Ny, z := Nz,
       vx := Nx - X, vy := Ny - Y, vz := Nz - Z,
       evidence := E + 1,
       seen := Tick,
       status := graduated(E + 1, S)}.

%% ⚠ ONCE CONFIRMED, ALWAYS CONFIRMED FOR THIS TRACK'S LIFE. The alternative —
%% dropping back to tentative on a missed tick — would make the network stop
%% cueing precisely when a target is hardest to see, which is when the cue is
%% worth most. A track that is genuinely gone is dropped by age, not demoted.
graduated(E, S) when E >= ?CONFIRM_EVIDENCE -> evoq_bit_flags:set(S, ?CONFIRMED);
graduated(_E, S) -> S.
