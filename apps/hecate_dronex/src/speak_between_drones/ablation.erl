%% @doc Whether the channel is load-bearing. PURE.
%%
%% THIS EXISTS SO THAT `THE DRONES COORDINATE' CAN BE A MEASUREMENT RATHER THAN AN
%% IMPRESSION PRODUCED BY WATCHING THEM.
%%
%% ==========================================================================
%% ⚠ SHIPPED WITH THE CHANNEL, NOT AFTER IT, AND THAT IS NOT TIDINESS
%% ==========================================================================
%%
%% A rising fitness in a population that HAS a channel says nothing about whether
%% the channel is why. Insight 054's lesson generalises: an instrument that is not
%% built and run goes silently blind, and the blindness looks exactly like a
%% result. The ablation is also impossible to add to history later, because a
%% period that was never ablated and a period whose ablation came back zero are
%% indistinguishable in the record unless the zero was written down at the time.
%%
%% Three numbers leave this module and charter rule 4 governs all three: publish
%% the exercise count beside the null.
%%
%%   SIGNAL VOLUME. Zero means nothing was ever transmitted, so every claim about
%%   coordination for that period is VOID rather than null. `void' is reported as
%%   its own flag for exactly that reason.
%%
%%   ABLATION DELTA. Zero means the channel is being driven and nothing depends on
%%   it.
%%
%%   CHANNEL ENTROPY. Zero means the channel is being driven with a CONSTANT,
%%   which is silence wearing a signal's clothes and would otherwise pass both
%%   other tests.
-module(ablation).

-include("airspace.hrl").

-export([measure/1, buckets/0, max_entropy/0, arms/0]).

-export_type([report/0]).

%% ⚠ ENTROPY OF A CONTINUOUS QUANTITY IS A FUNCTION OF THE BINNING, so the bin
%% count is part of the number and is exported rather than buried. Sixteen bins
%% over the channel's full range: a controller that splits its output into more
%% than sixteen meaningfully distinct values reads as saturated here, which is a
%% ceiling the reader should know about rather than a defect to hide.
-define(BUCKETS, 16).

%% Millibits, because everything on the reporting path is an integer.
-define(MILLI, 1000).

-type arm() :: air | ground | all.

-type report() :: #{engagements := non_neg_integer(),
                    ticks := non_neg_integer(),
                    volume := non_neg_integer(),
                    void := boolean(),
                    entropy := #{channel := [non_neg_integer()],
                                 mean := non_neg_integer()},
                    baseline := integer(),
                    muted := #{arm() => integer()},
                    delta := #{arm() => integer()}}.

-spec buckets() -> pos_integer().
buckets() -> ?BUCKETS.

%% What a channel using every bin equally would read: four bits.
-spec max_entropy() -> pos_integer().
max_entropy() -> round(math:log2(?BUCKETS) * ?MILLI).

-spec arms() -> [arm()].
arms() -> [air, ground, all].

%% @doc Run the same fights four ways and report what the channel was worth.
%%
%% ⚠ IT RERUNS RATHER THAN READING THE RECORDING. The published bout is decimated
%% and rounded to whole metres for a spectator, so deriving an ablation from it
%% would measure the encoding. The engine is deterministic and takes no seed, so
%% a rerun from the same arena and controllers is the same fight, and the mute is
%% then the only thing that differs. Frames are collected for the baseline arm
%% only; they are an observer and change nothing the engine does.
-spec measure([{#arena{}, #{term() => engagement:controller()}}]) -> report().
measure([]) -> empty();
measure(Fights) ->
    Base = [engagement:run(A, C, #{frames => true, network => ground_network:home()})
            || {A, C} <- Fights],
    Muted = maps:from_list([{Arm, scored(silenced(Fights, Arm))} || Arm <- arms()]),
    Rate = scored(Base),
    Volume = lists:sum([maps:get(signal_volume, R) || R <- Base]),
    #{engagements => length(Fights),
      ticks => lists:sum([maps:get(ticks, R) || R <- Base]),
      volume => Volume,
      void => Volume =:= 0,
      entropy => entropy(Base),
      baseline => Rate,
      muted => Muted,
      delta => maps:map(fun (_Arm, R) -> Rate - R end, Muted)}.

%% ⚠ ONE SIDE, NOT BOTH. See `engagement:muting/1': the attacker is silenced and
%% the defender is left exactly as it was, so the number is what the channel is
%% worth to the side that lost it rather than a difference that cancels.
%% ⚠ THE NETWORK IS PRESENT IN EVERY ARM, WHICH IS WHAT MAKES THE GROUND ARM MEAN
%% ANYTHING. Muting the ground bank measures whether CUEING mattered, and with no
%% network to mute there is nothing to measure — the arm would read zero for ever
%% and look like a finding. It reported exactly that from item 6 until the static
%% defence landed, correctly and uselessly.
silenced(Fights, Arm) ->
    [engagement:run(A, C, #{mute => #{attacker => Arm}, network => ground_network:home()})
     || {A, C} <- Fights].

empty() ->
    #{engagements => 0, ticks => 0, volume => 0, void => true,
      entropy => #{channel => lists:duplicate(4, 0), mean => 0},
      baseline => 0,
      muted => maps:from_list([{A, 0} || A <- arms()]),
      delta => maps:from_list([{A, 0} || A <- arms()])}.

%%==============================================================================
%% The score
%%==============================================================================

%% Percent, from the attacker's side, with a draw counting half. A draw is a
%% distinct outcome here (both sides alive at the tick limit) and folding it into
%% a loss would make a channel that buys survival look like one that buys nothing.
scored(Results) ->
    Points = lists:sum([points(maps:get(winner, R)) || R <- Results]),
    Points * 100 div (2 * length(Results)).

points(attacker) -> 2;
points(draw) -> 1;
points(defender) -> 0.

%%==============================================================================
%% The entropy
%%==============================================================================

%% Per channel, over every transmission by an attacking drone that was alive to
%% make it. Reported per channel AND as a mean, because a controller that drives
%% one channel richly and pins the other three is a real and interesting shape
%% that a mean alone would hide.
entropy(Results) ->
    Sent = lists:append([transmissions(maps:get(frames, R)) || R <- Results]),
    Per = [shannon([lists:nth(C, S) || S <- Sent]) || C <- lists:seq(1, 4)],
    #{channel => Per, mean => mean(Per)}.

transmissions(false) -> [];
transmissions(Frames) ->
    [D#drone.signal
     || A <- Frames, D <- airspace:drones(A),
        D#drone.side =:= attacker, not D#drone.dead, not D#drone.withdrawn,
        length(D#drone.signal) =:= 4].

shannon([]) -> 0;
shannon(Values) ->
    N = length(Values),
    Counts = maps:values(tally(Values)),
    round(-lists:sum([p(C, N) * math:log2(p(C, N)) || C <- Counts]) * ?MILLI).

p(Count, N) -> Count / N.

tally(Values) ->
    lists:foldl(fun (V, Acc) ->
                        B = bucket(V),
                        Acc#{B => maps:get(B, Acc, 0) + 1}
                end,
                #{}, Values).

%% ⚠ CLAMPED BEFORE BINNING, because the engine clamps a signal and a controller
%% that saturates would otherwise land in a phantom bin above the range and read
%% as extra variety.
bucket(V) ->
    #{signal_max := Max} = airspace:limits(),
    Clamped = fixed:clamp(V, -Max, Max),
    min(?BUCKETS - 1, (Clamped + Max) * ?BUCKETS div (2 * Max + 1)).

mean([]) -> 0;
mean(Xs) -> lists:sum(Xs) div length(Xs).
