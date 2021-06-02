defmodule ExHmac.Noncer.Client do
  @moduledoc false

  alias ExHmac.Noncer.Server

  ### Client
  def check(nonce, curr_ts, config) do
    with(
      {arrived_at, raw_result, result} <- check_call(nonce, curr_ts, config),
      _ <- save_meta_cast(raw_result, nonce, arrived_at, curr_ts, config)
    ) do
      result
    end
  end

  def check_call(nonce, curr_ts, config) do
    GenServer.call(Server, {nonce, curr_ts, config})
  end

  def save_meta_cast(raw_result, nonce, arrived_at, curr_ts, config) do
    GenServer.cast(Server, {:save_meta, raw_result, nonce, arrived_at, curr_ts, config})
  end
end
