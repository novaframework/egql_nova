-module(egql_nova).

-export([execute/2, execute/3]).

-spec execute(binary(), map()) -> map().
execute(Query, Params) ->
    execute(Query, Params, #{}).

-spec execute(binary(), map(), map()) -> map().
execute(Query, Params, Ctx) ->
    OpName = maps:get(<<"operationName">>, Params, undefined),
    Vars =
        case maps:get(<<"variables">>, Params, #{}) of
            null -> #{};
            V when is_map(V) -> V;
            _ -> #{}
        end,
    case graphql:parse(Query) of
        {ok, AST} ->
            try
                {ok, #{fun_env := FunEnv, ast := AST2}} = graphql:type_check(AST),
                ok = graphql:validate(AST2),
                Coerced = graphql:type_check_params(FunEnv, OpName, Vars),
                ExecCtx = Ctx#{
                    params => Coerced,
                    operation_name => OpName
                },
                graphql:execute(ExecCtx, AST2)
            catch
                throw:{'$graphql_throw', Err} ->
                    #{errors => graphql:format_errors(Ctx, Err)};
                error:Reason:Stack ->
                    logger:error("egql error: ~p~n~p", [Reason, Stack]),
                    #{errors => [#{message => format_reason(Reason)}]}
            end;
        {error, Err} ->
            #{errors => [#{message => format_reason(Err)}]}
    end.

format_reason(Reason) when is_binary(Reason) ->
    Reason;
format_reason(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
