%%% @doc HTTP surface for the scorer. GET /api/detection-quality -> scores JSON.
-module(query_detection_quality_api).

-export([init/2]).

init(Req0, [overview] = State) ->
    {ok, Scores} = query_detection_quality:overview(),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        jsx:encode(Scores), Req0),
    {ok, Req, State}.
