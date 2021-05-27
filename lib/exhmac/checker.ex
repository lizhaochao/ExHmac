defmodule ExHmac.Checker do
  @moduledoc false

  alias ExHmac.{Const, Error, Noncer}

  @default_timestamp_offset_seconds Const.default_timestamp_offset_seconds()
  @default_nonce_ttl Const.default_nonce_ttl()
  @warn_text "your timestamp may be a millisecond precision."
  @warn_radio 0.01

  ### Timestamp
  def check_timestamp(ts, precision, warn)
      when is_integer(ts) and ts > 0 and is_atom(precision) and is_atom(warn) do
    with curr_ts <- get_curr_ts(precision),
         :ignore <- warn_offset(curr_ts, ts, @warn_radio, warn),
         offset <- get_offset(precision, @default_timestamp_offset_seconds) do
      do_check_timestamp(curr_ts, ts, offset)
    else
      :should_warn -> Error.warn(@warn_text)
      err -> err
    end
  end

  def check_timestamp(_, _, _), do: raise(Error, "check timestamp error")

  def do_check_timestamp(curr_ts, ts, offset) when abs(curr_ts - ts) < offset, do: :ok
  def do_check_timestamp(_curr_ts, _ts, _offset), do: :timestamp_out_of_range

  def get_offset(:millisecond, default), do: default * 1000
  def get_offset(_prec, default), do: default

  def warn_offset(curr_ts, ts, radio, true) when abs(curr_ts / ts) < radio, do: :should_warn
  def warn_offset(_, _, _, _warn), do: :ignore

  ### Nonce
  def check_nonce(nonce) when is_bitstring(nonce) do
    with curr_ts <- get_curr_ts(),
         {:ok, created_at} <- get_created_at(nonce) do
      do_check_nonce(curr_ts, created_at, @default_nonce_ttl)
    else
      err -> err
    end
  end

  def check_nonce(_), do: raise(Error, "check nonce error")

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

  ### Helper
  defp get_curr_ts(prec \\ :second)
  defp get_curr_ts(:millisecond = prec), do: DateTime.utc_now() |> DateTime.to_unix(prec)
  defp get_curr_ts(_), do: DateTime.utc_now() |> DateTime.to_unix(:second)
end
