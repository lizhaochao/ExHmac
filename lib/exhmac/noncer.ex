defmodule ExHmac.Noncer do
  @moduledoc false

  alias ExHmac.Noncer.Server

  ### Client

  def check(nonce, curr_ts, config) do
    with(
      result <- check_call(nonce, curr_ts, config),
      _ <- save_meta_cast(nonce, curr_ts, config)
    ) do
      result
    end
  end

  def check_call(nonce, curr_ts, config) do
    GenServer.call(Server, {nonce, curr_ts, config})
  end

  def save_meta_cast(nonce, curr_ts, config) do
    GenServer.cast(Server, {:save_meta, nonce, curr_ts, config})
  end

  ###
  def gen_nonce(len), do: gen_random(trunc(len / 2))
  defp gen_random(bits), do: bits |> :crypto.strong_rand_bytes() |> Base.encode16()
end

defmodule ExHmac.Noncer.Worker do
  @moduledoc false

  alias ExHmac.Repo

  def check(nonce, curr_ts, config) do
    nonce
    |> get_and_update_nonce(curr_ts)
    |> do_check(curr_ts, config)
  end

  def get_and_update_nonce(nonce, curr_ts) do
    nonce
    |> Repo.get_and_update_nonce(curr_ts)
    |> case do
      nil -> :not_exists
      arrived_at -> arrived_at
    end
  end

  def do_check(arrived_at, curr_ts, config) when is_integer(arrived_at) do
    curr_ts
    |> expired(arrived_at, config)
    |> case do
      :not_expired -> :invalid_nonce
      :expired -> :ok
    end
  end

  def do_check(:not_exists = _arrived_at, _curr_ts, _config), do: :ok

  def expired(curr_ts, arrived_at, config) do
    with(
      %{nonce_ttl: ttl} <- config,
      true <- curr_ts - arrived_at >= ttl
    ) do
      :expired
    else
      false -> :not_expired
    end
  end

  ###
  def save_meta(nonce, curr_ts, config) do
    with(
      min <- ts_to_min(curr_ts, config),
      :ok <- update_shards(min, nonce),
      :ok <- update_count(min),
      :ok <- update_mins(min)
    ) do
      :ok
    end
  end

  def update_shards(min, nonce) do
    with(
      shard <- Repo.get_in([:meta, :shards, min]),
      new_shard <-
        (shard && nonce not in shard && MapSet.put(shard, nonce)) || MapSet.new([nonce])
    ) do
      Repo.update_in([:meta, :shards, min], new_shard)
    end
  end

  # TODO: count is not exactly, because shards is MapSet type.
  def update_count(min) do
    with(
      min_count <- Repo.get_in([:meta, :count, min]),
      new_min_count <- if(is_nil(min_count), do: 1, else: min_count + 1)
    ) do
      Repo.update_in([:meta, :count, min], new_min_count)
    end
  end

  def update_mins(min) do
    with(
      mins <- Repo.get_in([:meta, :mins]),
      true <- min not in mins,
      new_mins <- MapSet.put(mins, min)
    ) do
      Repo.update_in([:meta, :mins], new_mins)
    else
      false -> :ok
    end
  end

  def ts_to_min(ts, config) do
    %{precision: precision} = config

    case precision do
      :millisecond -> ts / 1000 / 60
      _second -> ts / 60
    end
    |> trunc()
  end

  ###
  def all, do: Repo.get_repo()
end

defmodule ExHmac.Noncer.Server do
  @moduledoc false

  ### Use GenServer To Make Sure Operations Is Atomic.
  use GenServer

  alias ExHmac.Noncer.Worker

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
    result = Worker.check(nonce, curr_ts, config)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:save_meta, nonce, curr_ts, config}, state) do
    Worker.save_meta(nonce, curr_ts, config)
    {:noreply, state}
  end
end
