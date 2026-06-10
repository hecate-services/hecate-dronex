%%% @doc Airspace-track aggregate state (edge domain). One per confirmed track.
-record(air_track_state, {
    track_id     :: binary() | undefined,
    drone        :: map() | undefined,            %% #{id, type}
    status_flags = 0 :: non_neg_integer(),
    x            :: number() | undefined,
    y            :: number() | undefined,
    alt          :: number() | undefined,
    confidence   :: float() | undefined,
    sensor_ids = [] :: [binary()],
    first_seen_at :: integer() | undefined,
    confirmed_at  :: integer() | undefined
}).
