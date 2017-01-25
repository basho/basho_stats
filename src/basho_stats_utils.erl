%% -------------------------------------------------------------------
%%
%% Copyright (c) 2011-2017 Basho Technologies, Inc.
%% Copyright (c) 2009 Dave Smith (dizzyd@dizzyd.com)
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc Unit Test Helpers.
%% The functions in this module are only visible when running tests.
-module(basho_stats_utils).

-ifdef(TEST).
-export([
    r_check/0,
    r_run/2
]).
-include_lib("eunit/include/eunit.hrl").

-define(R_KEY, {?MODULE, 'R_exe'}).
-define(P_KEY, {?MODULE, 'R_port'}).
-define(R_ERR, {error, missing_R_executable}).
-define(FMT(Str, Args), lists:flatten(io_lib:format(Str, Args))).

%% ===================================================================
%% Unit Test Helpers
%% ===================================================================

-spec r_check() -> ok | ?R_ERR.
%%
%% Checks for the presence of the R executable.
%%
r_check() ->
    case r_exe() of
        {error, _} = Err ->
            Err;
        _ ->
            ok
    end.

-spec r_run(Input :: [integer()], Command :: string()) -> [number()].
%%
%% Runs R Command with Input.
%%
r_run(Input, Command) ->
    case r_port() of
        {ok, Port} ->
            InputStr = [integer_to_list(I) || I <- Input],
            port_command(Port, ?FMT("x <- c(~s)\n", [string:join(InputStr, ",")])),
            port_command(Port, ?FMT("write(~s, ncolumns=1, file=stdout())\n", [Command])),
            port_command(Port, "write('', file=stdout())\n"),
            r_simple_read_loop(Port, []);
        {error, _} = Err ->
            Err
    end.

%% ===================================================================
%% Internal
%% ===================================================================

-spec r_exe() -> string() | ?R_ERR.
r_exe() ->
    case erlang:get(?R_KEY) of
        undefined ->
            R = case os:find_executable("R") of
                false ->
                    ?R_ERR;
                File ->
                    File
            end,
            _ = erlang:put(?R_KEY, R),
            R;
        Val ->
            Val
    end.

-spec r_port() -> {ok, port()} | {error, term()}.
r_port() ->
    case erlang:get(?P_KEY) of
        undefined ->
            case r_exe() of
                {error, _} = Err ->
                    Err;
                Exe ->
                    Port = erlang:open_port({spawn_executable, Exe}, [
                        {args, ["--vanilla", "--slave"]}, {line, 16384},
                        use_stdio, exit_status, stderr_to_stdout, hide]),
                    case r_port_(Port) of
                        {error, _} = PErr ->
                            PErr;
                        ok ->
                            _ = erlang:put(?P_KEY, Port),
                            {ok, Port}
                    end
            end;
        Prev ->
            case r_port_(Prev) of
                {error, _} = PErr ->
                    _ = erlang:erase(?P_KEY),
                    PErr;
                ok ->
                    {ok, Prev}
            end
    end.

-spec r_port_(Port :: port()) -> ok | {error, term()}.
%% Check the status of the port
r_port_(Port) ->
    try
        _ = erlang:port_command(Port, "write('', file=stdout())\n"),
        receive
            {Port, {data, {eol, []}}} ->
                ok;
            {Port, {data, {eol, Other}}} ->
                {error, Other}
        end
    catch
        error:badarg ->
            {error, port_closed}
    end.

r_simple_read_loop(Port, Acc) ->
    receive
        {Port, {data, {eol, []}}} ->
            lists:reverse(Acc);
        {Port, {data, {eol, Line}}} ->
            case Line of
                "Error"++_ ->
                    Error = get_error(Port, [Line]),
                    exit({error, Error});
                _ ->
                    r_simple_read_loop(Port, [to_number(Line) | Acc])
            end;
        {Port, {exit_status, _}} ->
            lists:reverse(Acc)
    end.

get_error(Port, Acc) ->
    receive
        {Port, {data, {eol, []}}} ->
            lists:reverse(Acc);
        {Port, {data, {eol, Line}}} ->
            get_error(Port, [Line | Acc]);
        {Port, {exit_status, _}} ->
            lists:reverse(Acc)
    end.

to_number(Str) ->
    case catch(list_to_integer(Str)) of
        {'EXIT', _} ->
            list_to_float(Str);
        Value ->
            Value
    end.

-endif. % TEST

