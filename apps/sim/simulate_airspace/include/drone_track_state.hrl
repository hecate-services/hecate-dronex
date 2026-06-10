%%% @doc Ground-truth drone-track aggregate state.
%%%
%%% This is the SIMULATOR's truth. It is internal: it never crosses the mesh
%%% (so fusion cannot cheat). The scorer reads it locally to grade fusion.
-record(drone_track_state, {
    drone_id   :: binary() | undefined,
    drone_type :: binary() | undefined,
    remote_id  :: present | absent | undefined,  %% does it broadcast Remote ID?
    status_flags = 0 :: non_neg_integer(),
    x          :: number() | undefined,          %% site-local metres
    y          :: number() | undefined,
    alt        :: number() | undefined,
    entered_at :: integer() | undefined,         %% ms
    departed_at :: integer() | undefined
}).
