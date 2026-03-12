# egql_nova

[Nova](https://github.com/novaframework/nova) integration for [egql](https://github.com/MarkoMin/egql) GraphQL.

Provides a controller for handling GraphQL queries over HTTP, a GraphiQL IDE endpoint, and a Nova plugin for injecting request context into GraphQL execution.

## Installation

```erlang
{deps, [
    {egql_nova, {git, "https://github.com/novaframework/egql_nova.git", {branch, "main"}}}
]}.
```

## Setup

### 1. Define your schema

Create a `.graphql` schema file and resource modules following the [egql documentation](https://github.com/MarkoMin/egql).

```graphql
type Query {
  hello(name: String = "World"): String!
}
```

```erlang
-module(query_resource).
-export([execute/4]).

execute(_Ctx, _Obj, <<"hello">>, #{<<"name">> := Name}) ->
    {ok, <<"Hello, ", Name/binary, "!">>}.
```

### 2. Load the schema on application start

```erlang
init_schema() ->
    {ok, SchemaData} = file:read_file(schema_path()),
    Mapping = #{
        scalars => #{default => scalar_resource},
        interfaces => #{default => resolve_resource},
        objects => #{
            'Query' => query_resource,
            'Mutation' => mutation_resource
        }
    },
    ok = graphql:load_schema(Mapping, SchemaData),
    ok = graphql:insert_schema_definition(
        {root, #{query => 'Query', mutation => 'Mutation', interfaces => []}}
    ),
    ok = graphql:validate_schema().
```

### 3. Add routes

```erlang
routes(_Env) ->
    [#{
        prefix => "/api",
        security => false,
        routes => [
            {"/graphql", fun egql_nova_controller:graphql/1, #{methods => [post]}},
            {"/graphql", fun egql_nova_controller:graphiql/1, #{methods => [get]}}
        ]
    }].
```

### 4. Query

```bash
curl -X POST http://localhost:8080/api/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ hello(name: \"Erlang\") }"}'
```

```json
{"data": {"hello": "Hello, Erlang!"}}
```

## Context Plugin

Use `egql_nova_plug` to inject request context (auth, session, etc.) into GraphQL execution:

```erlang
%% sys.config
{nova, [
    {plugins, [
        {pre_request, nova_request_plugin, #{decode_json_body => true}},
        {pre_request, egql_nova_plug, #{
            context_fun => fun my_auth:build_context/1
        }}
    ]}
]}
```

```erlang
-module(my_auth).
-export([build_context/1]).

build_context(Req) ->
    Token = cowboy_req:header(<<"authorization">>, Req, undefined),
    case verify_token(Token) of
        {ok, User} -> #{current_user => User};
        _ -> #{}
    end.
```

The context is then available in your resource modules:

```erlang
execute(#{current_user := User}, _Obj, <<"me">>, _Args) ->
    {ok, User};
execute(#{current_user := undefined}, _Obj, <<"me">>, _Args) ->
    {error, <<"Unauthorized">>}.
```

## GraphiQL

Visit `GET /api/graphql` in your browser for the GraphiQL IDE.

## License

MIT
