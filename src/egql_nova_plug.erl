-module(egql_nova_plug).

-export([pre_request/2, post_request/2]).

%% Pre-request plugin for injecting GraphQL context from the Nova request.
%% Add to your sys.config plugins:
%%   {pre_request, egql_nova_plug, #{context_fun => fun my_mod:build_ctx/1}}
%%
%% The context_fun receives the full cowboy request map and should return
%% a map that gets merged into the GraphQL execution context.

pre_request(Req, #{context_fun := Fun} = _Options) when is_function(Fun, 1) ->
    Ctx = Fun(Req),
    Req2 =
        case Req of
            #{extra_state := ES} when is_map(ES) ->
                ExistingCtx = maps:get(context, ES, #{}),
                Req#{extra_state => ES#{context => maps:merge(ExistingCtx, Ctx)}};
            _ ->
                Req#{extra_state => #{context => Ctx}}
        end,
    {ok, Req2};
pre_request(Req, _Options) ->
    {ok, Req}.

post_request(Req, _Options) ->
    {ok, Req}.
