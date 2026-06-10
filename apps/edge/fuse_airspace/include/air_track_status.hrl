%%% @doc Airspace-track status bit flags (powers of 2, evoq_bit_flags).
-define(TRACK_CONFIRMED, 1).   %% 2^0 — a real track, escalation-grade
-define(TRACK_LOST,      2).   %% 2^1 — contact lost, track closed
