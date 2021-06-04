defmodule ExHmac.Noncer.Server do
  @moduledoc false

  ### Use GenServer To Make Sure Operations Is Atomic.
  use GenServer

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer.GarbageCollector, as: GC

  @gc_interval_milli Config.get_gc_interval_milli()

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
  def init(:ok) do
    gc_timer_fire()
    {:ok, nil}
  end

  @impl true
  def handle_info(:collect, state) do
    with(
      _ <- GC.collect(),
      _ <- gc_timer_fire()
    ) do
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_, state), do: {:ok, state}

  @impl true
  def handle_call({nonce, curr_ts, ttl, precision}, _from, state) do
    result = Noncer.check(nonce, curr_ts, ttl, precision)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:save_meta, raw_result, nonce, arrived_at, curr_ts, precision}, state) do
    Noncer.save_meta(raw_result, nonce, arrived_at, curr_ts, precision)
    {:noreply, state}
  end

  def gc_timer_fire do
    Process.send_after(self(), :collect, @gc_interval_milli)
  end
end
