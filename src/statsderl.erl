-module(statsderl).
-include("statsderl.hrl").

%% public
-export([
    counter/3,
    decrement/3,
    gauge/3,
    gauge_decrement/3,
    gauge_increment/3,
    increment/3,
    timing/3,
    timing_fun/3,
    timing_now/3
]).

%% public
-spec counter(key(), value(), sample_rate()) -> ok.

counter(Key, Value, SampleRate) ->
    maybe_cast(counter, Key, Value, SampleRate).

-spec decrement(key(), value(), sample_rate()) -> ok.

decrement(Key, Value, SampleRate) when Value >= 0 ->
    maybe_cast(counter, Key, -Value, SampleRate).

-spec gauge(key(), value(), sample_rate()) -> ok.

gauge(Key, Value, SampleRate) when Value >= 0 ->
    maybe_cast(gauge, Key, Value, SampleRate).

-spec gauge_decrement(key(), value(), sample_rate()) -> ok.

gauge_decrement(Key, Value, SampleRate) when Value >= 0 ->
    maybe_cast(gauge_decrement, Key, Value, SampleRate).

-spec gauge_increment(key(), value(), sample_rate()) -> ok.

gauge_increment(Key, Value, SampleRate) when Value >= 0 ->
    maybe_cast(gauge_increment, Key, Value, SampleRate).

-spec increment(key(), value(), sample_rate()) -> ok.

increment(Key, Value, SampleRate) when Value >= 0 ->
    maybe_cast(counter, Key, Value, SampleRate).

-spec timing(key(), value(), sample_rate()) -> ok.

timing(Key, Value, SampleRate) ->
    maybe_cast(timing, Key, Value, SampleRate).

-spec timing_fun(key(), fun(), sample_rate()) -> ok.

timing_fun(Key, Fun, SampleRate) ->
    Timestamp = statsderl_utils:timestamp(),
    Result = Fun(),
    timing_now(Key, Timestamp, SampleRate),
    Result.

-spec timing_now(key(), erlang:timestamp(), sample_rate()) -> ok.

timing_now(Key, Timestamp, SampleRate) ->
    Timestamp2 = statsderl_utils:timestamp(),
    Value = timer:now_diff(Timestamp2, Timestamp) div 1000,
    timing(Key, Value, SampleRate).

%% private
cast(OpCode, Key, Value, SampleRate) ->
    ServerName = statsderl_utils:random_server(),
    cast(OpCode, Key, Value, SampleRate, ServerName).

cast(OpCode, Key, Value, SampleRate, ServerName) ->
    Packet = statsderl_protocol:encode(OpCode, Key, Value, SampleRate),
    send(ServerName, {cast, Packet}).

maybe_cast(OpCode, Key, Value, 1) ->
    cast(OpCode, Key, Value, 1);
maybe_cast(OpCode, Key, Value, 1.0) ->
    cast(OpCode, Key, Value, 1);
maybe_cast(OpCode, Key, Value, SampleRate) ->
    Rand = statsderl_utils:random(?MAX_UNSIGNED_INT_32),
    case Rand =< SampleRate * ?MAX_UNSIGNED_INT_32 of
        true  ->
            N = Rand rem ?POOL_SIZE + 1,
            ServerName = statsderl_utils:server_name(N),
            cast(OpCode, Key, Value, SampleRate, ServerName);
        false ->
            ok
    end.

send(ServerName, Msg) ->
    try
        whereis(ServerName) ! Msg,
        ok
    catch
        error:badarg ->
            ok
    end.
