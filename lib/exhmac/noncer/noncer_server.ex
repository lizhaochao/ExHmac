defmodule ExHmac.Noncer.Server do
  @moduledoc false

  ### Use GenServer To Make Sure Operations Is Atomic.
  use GenServer

  alias ExHmac.Noncer

  def start_link(opts) when is_list(opts) do
    with(
      impl_m <- __MODULE__,
      repo_name <- impl_m,
      name_opt <- [name: repo_name]
    ) do
      GenServer.start_link(impl_m, :ok, opts ++ name_opt)
    end
  end

  @impl true
  def init(:ok), do: {:ok, nil}

  @impl true
  def handle_call({nonce, curr_ts, config}, _from, state) do
    result = Noncer.check(nonce, curr_ts, config)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:save_meta, raw_result, nonce, arrived_at, curr_ts, config}, state) do
    Noncer.save_meta(raw_result, nonce, arrived_at, curr_ts, config)
    {:noreply, state}
  end
end
