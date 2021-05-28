defmodule ExHmac.Checker do
  @moduledoc false

  alias ExHmac.{Error, Noncer, Util}

  @warn_text "your timestamp may be a millisecond precision."
  @warn_ratio 0.01

  ### Timestamp
  def check_timestamp(ts, opts) when is_integer(ts) and ts > 0 and is_map(opts) do
    %{
      precision: precision,
      warn: warn,
      timestamp_offset: timestamp_offset
    } = opts

    with curr_ts <- Util.get_curr_ts(precision),
         _ <- warn_offset(curr_ts, ts, warn, @warn_text, @warn_ratio),
         offset <- get_offset(precision, timestamp_offset) do
      do_check_timestamp(curr_ts, ts, offset)
    end
  end

  def check_timestamp(_, _), do: raise(Error, "check timestamp error")

  def do_check_timestamp(curr_ts, ts, offset) when abs(curr_ts - ts) < offset, do: :ok
  def do_check_timestamp(_curr_ts, _ts, _offset), do: :timestamp_out_of_range

  def get_offset(:millisecond, default), do: default * 1000
  def get_offset(_prec, default), do: default

  def warn_offset(curr_ts, ts, warn, warn_text, warn_ratio) do
    do_warn_offset(curr_ts, ts, warn_ratio, warn)
    |> case do
      :should_warn -> Error.warn(warn_text, warn)
      _ -> nil
    end
  end

  def do_warn_offset(curr_ts, ts, ratio, true) when abs(curr_ts / ts) < ratio, do: :should_warn
  def do_warn_offset(_, _, _, _warn), do: :ignore

  ### Nonce
  def check_nonce(nonce, opts) when is_bitstring(nonce) and is_map(opts) do
    with curr_ts <- Util.get_curr_ts(),
         %{nonce_ttl: nonce_ttl} <- opts,
         {:ok, created_at} <- get_created_at(nonce) do
      do_check_nonce(curr_ts, created_at, nonce_ttl)
    else
      _ -> raise(Error, "opts error")
    end
  end

  def check_nonce(_, _), do: raise(Error, "check nonce error")

  def do_check_nonce(_curr_ts, nil = _created_at, _ttl), do: :ok
  def do_check_nonce(curr_ts, created_at, ttl) when curr_ts - created_at > ttl, do: :ok
  def do_check_nonce(_curr_ts, _created_at, _ttl), do: :invalid_nonce

  def get_created_at(nonce) do
    nonce
    |> Noncer.get_created_at()
    |> case do
      created_at when is_nil(created_at) or is_integer(created_at) -> {:ok, created_at}
      _ -> :invalid_storage
    end
  end
end
