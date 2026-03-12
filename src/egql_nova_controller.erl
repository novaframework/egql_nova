-module(egql_nova_controller).

-export([graphql/1, graphiql/1]).

%% POST /graphql
%% Expects JSON body with query, variables, operationName.
%% Pass context via route extra: #{context => #{current_user => ...}}
graphql(#{json := Body} = Req) ->
    Query = maps:get(<<"query">>, Body, <<>>),
    Ctx = build_context(Req),
    Result = egql_nova:execute(Query, Body, Ctx),
    {json, 200, #{}, Result};
graphql(#{body := RawBody} = Req) ->
    Body = jsone:decode(RawBody),
    Query = maps:get(<<"query">>, Body, <<>>),
    Ctx = build_context(Req),
    Result = egql_nova:execute(Query, Body, Ctx),
    {json, 200, #{}, Result}.

%% GET /graphql — serves GraphiQL IDE
graphiql(_Req) ->
    {ok, 200, #{<<"content-type">> => <<"text/html">>}, graphiql_html()}.

build_context(Req) ->
    ExtraCtx = case Req of
        #{extra_state := #{context := C}} when is_map(C) -> C;
        _ -> #{}
    end,
    ExtraCtx.

graphiql_html() ->
    <<"<!DOCTYPE html>
<html>
<head>
  <title>GraphiQL</title>
  <style>
    body { height: 100vh; margin: 0; overflow: hidden; }
    #graphiql { height: 100vh; }
  </style>
  <script crossorigin src=\"https://unpkg.com/react@18/umd/react.production.min.js\"></script>
  <script crossorigin src=\"https://unpkg.com/react-dom@18/umd/react-dom.production.min.js\"></script>
  <link rel=\"stylesheet\" href=\"https://unpkg.com/graphiql/graphiql.min.css\" />
  <script crossorigin src=\"https://unpkg.com/graphiql/graphiql.min.js\"></script>
</head>
<body>
  <div id=\"graphiql\">Loading...</div>
  <script>
    const fetcher = GraphiQL.createFetcher({ url: window.location.pathname });
    ReactDOM.createRoot(document.getElementById('graphiql'))
      .render(React.createElement(GraphiQL, { fetcher }));
  </script>
</body>
</html>">>.
