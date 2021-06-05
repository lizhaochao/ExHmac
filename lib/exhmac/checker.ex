defmodule ExHmac.Checker do
  @moduledoc false

  alias ExHmac.{Config, Error, Util}
  alias ExHmac.Noncer.Client, as: NoncerClient

  @warn_text "your timestamp may be a millisecond precision."
  @warn_ratio 0.01

  ### Timestamp
  def check_timestamp(ts, config) when is_integer(ts) and ts > 0 and is_map(config) do
    with(
      %{warn: warn} <- config,
      precision <- Config.get_precision(),
      timestamp_offset_secs <- Config.get_timestamp_offset_secs(),
      curr_ts <- Util.get_curr_ts(precision),
      _ <- warn_offset(curr_ts, ts, warn, @warn_text, @warn_ratio),
      offset <- get_offset(precision, timestamp_offset_secs)
    ) do
      do_check_timestamp(curr_ts, ts, offset)
    end
  end

  def check_timestamp(_, _), do: raise(Error, "check timestamp error")

  def do_check_timestamp(curr_ts, ts, offset) when abs(curr_ts - ts) < offset, do: :ok
  def do_check_timestamp(_curr_ts, _ts, _offset), do: :timestamp_out_of_range

  def get_offset(:millisecond, default), do: default * 1000
  def get_offset(_second, default), do: default

  def warn_offset(curr_ts, ts, warn, warn_text, warn_ratio) do
    do_warn_offset(curr_ts, ts, warn_ratio)
    |> case do
      :should_warn -> Error.warn(warn_text, warn)
      _ -> nil
    end
  end

  def do_warn_offset(curr_ts, ts, ratio) when abs(curr_ts / ts) < ratio, do: :should_warn
  def do_warn_offset(_, _, _), do: :ignore

  ### Nonce
  def check_nonce(nonce, %{} = config) when is_bitstring(nonce) do
    with(
      %{impl_m: impl_m} <- config,
      {f, _a} <- __ENV__.function,
      curr_ts <- Util.get_curr_ts(),
      nonce_freezing_secs <- Config.get_nonce_freezing_secs(),
      precision <- Config.get_precision(),
      disable_noncer <- Config.get_disable_noncer(),
      args <- [nonce, curr_ts, nonce_freezing_secs, precision]
    ) do
      cond do
        function_exported?(impl_m, f, 4) -> apply(impl_m, f, args)
        disable_noncer -> :ok
        true -> apply(NoncerClient, :check, args)
      end
    end
  end

  def check_nonce(_, _), do: raise(Error, "check nonce error")

  ###
  def require_function!(impl_m, f, a) do
    if function_exported?(impl_m, f, a) do
      :ignore
    else
      raise Error, "!!! not implement #{to_string(impl_m)}.#{to_string(f)}/#{a} function !!!"
    end
  end

  def keyword_or_map!(term, title) do
    if Keyword.keyword?(term) or is_map(term) do
      term
    else
      raise Error, "#{title}: must be keyword or map"
    end
  end
end
