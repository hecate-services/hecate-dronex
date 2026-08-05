%%% @doc Behaviour: a sensor model turns ground truth into what THIS sensor
%%% would actually report, uncertainty and all.
%%%
%%% This is where the realism budget goes (see DESIGN_DRONEX_SIMULATION.md):
%%% detection probability, bearing/range noise, false alarms, confusion. An
%%% L1 (fact-level) implementation computes a noisy fact directly; an L3
%%% (signal-level) implementation would render a signal and run the real
%%% classifier over it. Same callback, same fact out, so fusion never knows.
%%%
%%%   Drone :: #{id, type, x, y, alt, remote_id, t, ...}   (ground truth)
%%%   Sensor :: #{id, modality, x, y, range_m, p_detect, ...} (placement + model knobs)
%%%   Env :: #{wind_ms, visibility, ...}                   (scenario environment)
%%%
%%% Returns {ok, Fact} where Fact is an airspace_contact_observed:new/1 map,
%%% or `miss` when the sensor does not detect the drone this instant.
-module(dronex_sensor_model).

-callback observe(Drone :: map(), Sensor :: map(), Env :: map()) ->
    {ok, Fact :: map()} | miss.
