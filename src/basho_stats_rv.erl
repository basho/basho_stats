%% -------------------------------------------------------------------
%%
%% Copyright (c) 2010-2017 Basho Technologies, Inc.
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

%% @doc Random values.
-module(basho_stats_rv).

-export([
    exponential/1,
    normal/2,
    poisson/1,
    uniform/0
]).

%% ====================================================================
%% Public API
%% ====================================================================

%%
%% @doc Generates a uniformly-distributed random float.
%%
-ifdef(NO_RAND_MODULE).
uniform() ->
    % Make sure the PRNG in this process is seeded.
    % Alas, it *could* have been previously seeded with the default, but we
    % can't tell that, and if someone took care seeding it with good entropy
    % we don't want to throw that away on them.
    case erlang:get(random_seed) of
        undefined ->
            {A, B, C} = os:timestamp(),
            _ = random:seed(
                erlang:phash2({A, erlang:make_ref()}, 1 bsl 32),
                erlang:phash2({B, erlang:self()}, 1 bsl 32), C),
            ok;
        _ ->
            ok
    end,
    random:uniform().
-else.
-compile({inline, [uniform/0]}).
uniform() ->
    rand:uniform().
-endif.

%%
%% @doc Generates an exponential-distributed random variable, using inverse function.
%%
exponential(Lambda) ->
    -math:log(uniform()) / Lambda.

%%
%% @doc Generates a Poisson-distributed random variable by summing exponential rvs.
%%
%% Warning: This may be slow!!
%%
poisson(Lambda) ->
    poisson_rv_loop(Lambda, 0.0, -1).

%%
%% @doc Generates a Normal-distributed random variable, using Box-Muller method.
%%
normal(Mean, Sigma) ->
    Rv1 = uniform(),
    Rv2 = uniform(),
    Rho = math:sqrt(-2 * math:log(1-Rv2)),
    Rho * math:cos(2 * math:pi() * Rv1) * Sigma + Mean.


%% ====================================================================
%% Internal functions
%% ====================================================================

poisson_rv_loop(Lambda, Sum, N) when Sum < Lambda ->
    poisson_rv_loop(Lambda, Sum - math:log(uniform()), N+1);
poisson_rv_loop(_Lambda, _Sum, N) ->
    N.
