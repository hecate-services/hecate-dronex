%%% @doc Drone-track status bit flags (powers of 2, evoq_bit_flags).
-define(DRONE_IN_AIRSPACE, 1).   %% 2^0 — entered, currently tracked as ground truth
-define(DRONE_DEPARTED,    2).   %% 2^1 — left the airspace
