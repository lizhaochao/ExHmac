defmodule ExHmac.Noncer.Client do
  @moduledoc false

  alias ExHmac.Noncer.Server

  ### Client
  def check(nonce, curr_ts, freezing_secs, precision) do
    with(
      {arrived_at, raw_result, result} <- check_call(nonce, curr_ts, freezing_secs, precision),
      _ <- save_meta_cast(raw_result, nonce, arrived_at, curr_ts, precision)
    ) do
      result
    end
  end

  def check_call(nonce, curr_ts, freezing_secs, precision) do
    GenServer.call(Server, {nonce, curr_ts, freezing_secs, precision})
  end

  def save_meta_cast(raw_result, nonce, arrived_at, curr_ts, precision) do
    GenServer.cast(Server, {:save_meta, raw_result, nonce, arrived_at, curr_ts, precision})
  end
end
