%%% @doc Remote-ID sensor model (L1, fact level).
%%%
%%% Remote ID is a legally mandated WiFi/BT broadcast: a compliant drone
%%% announces its identity and GPS position. So this model is near-perfect
%%% WHEN the drone broadcasts, and blind otherwise. That presence/absence is
%%% the dominant variable; range and a small GPS error are secondary.
%%%
%%% This is where the realism budget lives (see DESIGN_DRONEX_SIMULATION.md);
%%% an L3 implementation behind the same behaviour would instead receive a
%%% real radio capture and decode it.
-module(remote_id_sensor_model).
-behaviour(dronex_sensor_model).

-export([observe/3]).

-define(GPS_SIGMA_M, 3.0).        %% Remote-ID position is GPS-accurate
-define(CONFIDENCE,  0.95).

-spec observe(map(), map(), map()) -> {ok, map()} | miss.
observe(Drone, Sensor, _Env) ->
    case maps:get(remote_id, Drone, absent) of
        present -> observe_broadcasting(Drone, Sensor);
        _       -> miss            %% non-compliant / autonomous: invisible to Remote ID
    end.

observe_broadcasting(Drone, Sensor) ->
    DX   = num(maps:get(x, Drone)) - num(maps:get(x, Sensor)),
    DY   = num(maps:get(y, Drone)) - num(maps:get(y, Sensor)),
    Dist = math:sqrt(DX * DX + DY * DY),
    Range   = num(maps:get(range_m, Sensor, 800)),
    PDetect = num(maps:get(p_detect, Sensor, 0.97)),
    case Dist =< Range andalso rand:uniform() =< PDetect of
        false -> miss;
        true  -> {ok, contact(Drone, Sensor, Dist)}
    end.

contact(Drone, Sensor, Dist) ->
    NX = num(maps:get(x, Drone)) + rand:normal() * ?GPS_SIGMA_M,
    NY = num(maps:get(y, Drone)) + rand:normal() * ?GPS_SIGMA_M,
    airspace_contact_observed:new(#{
        sensor_id   => maps:get(id, Sensor),
        modality    => remote_id,
        observed_at => maps:get(observed_at, Drone, erlang:system_time(millisecond)),
        position    => #{x => NX, y => NY, alt => num(maps:get(alt, Drone, 0))},
        range_m     => Dist,
        drone       => #{id   => maps:get(drone_id, Drone),
                         type => maps:get(drone_type, Drone, <<"unknown">>)},
        confidence  => ?CONFIDENCE}).

num(N) when is_number(N) -> N;
num(_)                   -> 0.
