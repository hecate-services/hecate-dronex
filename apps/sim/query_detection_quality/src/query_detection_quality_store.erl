%%% @doc SQLite store for the detection-quality scorer: ground truth (from the
%%% simulator's internal events) and estimates (from track_confirmed facts).
%%% Writes are async casts; reads are calls. esqlite3 rows come back as lists.
-module(query_detection_quality_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([record_ground_truth/5, record_estimate/6]).
-export([ground_truth_drones/0, estimate_drones/0, entry_time/1,
         first_estimate_time/1, ground_truth_points/1, estimate_points/1,
         false_track_count/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: term()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% --- writes (async) ---
-spec record_ground_truth(binary(), integer(), number(), number(), number()) -> ok.
record_ground_truth(DroneId, T, X, Y, Alt) ->
    gen_server:cast(?MODULE, {ground_truth, DroneId, T, n(X), n(Y), n(Alt)}).

-spec record_estimate(binary(), binary(), integer(), number(), number(), number()) -> ok.
record_estimate(TrackId, DroneId, T, X, Y, Conf) ->
    gen_server:cast(?MODULE, {estimate, TrackId, DroneId, T, n(X), n(Y), n(Conf)}).

%% --- reads (sync) ---
ground_truth_drones()   -> gen_server:call(?MODULE, ground_truth_drones).
estimate_drones()       -> gen_server:call(?MODULE, estimate_drones).
entry_time(DroneId)     -> gen_server:call(?MODULE, {entry_time, DroneId}).
first_estimate_time(D)  -> gen_server:call(?MODULE, {first_estimate_time, D}).
ground_truth_points(D)  -> gen_server:call(?MODULE, {ground_truth_points, D}).
estimate_points(D)      -> gen_server:call(?MODULE, {estimate_points, D}).
false_track_count()     -> gen_server:call(?MODULE, false_track_count).

%%--------------------------------------------------------------------

init([]) ->
    {ok, Db} = open(),
    {ok, #state{db = Db}}.

handle_cast({ground_truth, D, T, X, Y, Alt}, #state{db = Db} = S) ->
    _ = esqlite3:q(Db, "INSERT OR REPLACE INTO ground_truth(drone_id,t,x,y,alt) "
                       "VALUES(?1,?2,?3,?4,?5);", [D, T, X, Y, Alt]),
    {noreply, S};
handle_cast({estimate, Tk, D, T, X, Y, C}, #state{db = Db} = S) ->
    _ = esqlite3:q(Db, "INSERT OR REPLACE INTO estimates(track_id,drone_id,t,x,y,confidence) "
                       "VALUES(?1,?2,?3,?4,?5,?6);", [Tk, D, T, X, Y, C]),
    {noreply, S};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_call(ground_truth_drones, _F, #state{db = Db} = S) ->
    {reply, col(esqlite3:q(Db, "SELECT DISTINCT drone_id FROM ground_truth;")), S};
handle_call(estimate_drones, _F, #state{db = Db} = S) ->
    {reply, col(esqlite3:q(Db, "SELECT DISTINCT drone_id FROM estimates;")), S};
handle_call({entry_time, D}, _F, #state{db = Db} = S) ->
    {reply, scalar(esqlite3:q(Db, "SELECT MIN(t) FROM ground_truth WHERE drone_id=?1;", [D])), S};
handle_call({first_estimate_time, D}, _F, #state{db = Db} = S) ->
    {reply, scalar(esqlite3:q(Db, "SELECT MIN(t) FROM estimates WHERE drone_id=?1;", [D])), S};
handle_call({ground_truth_points, D}, _F, #state{db = Db} = S) ->
    {reply, [{T, X, Y} || [T, X, Y] <- esqlite3:q(Db,
        "SELECT t,x,y FROM ground_truth WHERE drone_id=?1 ORDER BY t;", [D])], S};
handle_call({estimate_points, D}, _F, #state{db = Db} = S) ->
    {reply, [{T, X, Y} || [T, X, Y] <- esqlite3:q(Db,
        "SELECT t,x,y FROM estimates WHERE drone_id=?1 ORDER BY t;", [D])], S};
handle_call(false_track_count, _F, #state{db = Db} = S) ->
    Q = "SELECT COUNT(DISTINCT track_id) FROM estimates "
        "WHERE drone_id NOT IN (SELECT drone_id FROM ground_truth);",
    {reply, scalar_int(esqlite3:q(Db, Q)), S};
handle_call(_Msg, _F, S) ->
    {reply, {error, unknown_call}, S}.

handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, #state{db = Db}) -> catch esqlite3:close(Db), ok.

%%--------------------------------------------------------------------

open() ->
    DbPath = filename:join([hecate_dronex_service:data_dir(), "read_models",
                            "detection_quality.sqlite"]),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db,
        "CREATE TABLE IF NOT EXISTS ground_truth("
        "  drone_id TEXT, t INTEGER, x REAL, y REAL, alt REAL,"
        "  PRIMARY KEY(drone_id, t));"),
    ok = esqlite3:exec(Db,
        "CREATE TABLE IF NOT EXISTS estimates("
        "  track_id TEXT, drone_id TEXT, t INTEGER, x REAL, y REAL, confidence REAL,"
        "  PRIMARY KEY(track_id, t));"),
    {ok, Db}.

%% rows -> first column of each row
col(Rows) -> [V || [V | _] <- Rows].

scalar([[V] | _]) when V =/= undefined, V =/= null -> {ok, V};
scalar(_) -> {error, not_found}.

scalar_int([[V] | _]) when is_integer(V) -> V;
scalar_int(_) -> 0.

n(V) when is_number(V) -> float(V);
n(_)                   -> 0.0.
