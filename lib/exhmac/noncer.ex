defmodule ExHmac.Noncer do
  @moduledoc false

  ### Client

  def check(nonce, curr_ts, config), do: GenServer.call(__MODULE__, {nonce, curr_ts, config})

  ###
  def gen_nonce(len), do: gen_random(trunc(len / 2))
  defp gen_random(bits), do: bits |> :crypto.strong_rand_bytes() |> Base.encode16()
end

defmodule ExHmac.Noncer.Worker do
  @moduledoc false

  alias ExHmac.Repo

  # TODO: improve save operation execute performance
  def check(nonce, curr_ts, config) do
    with(
      arrived_at <- get_and_update_nonce(nonce, curr_ts),
      result <- do_check(arrived_at, curr_ts, config),
      _ <- save(nonce, curr_ts, config)
    ) do
      result
    end
  end

  def get_and_update_nonce(nonce, curr_ts) do
    fun = fn nonces ->
      arrived_at = Map.get(nonces, nonce, :not_exists)
      new_nonces = Map.put(nonces, nonce, curr_ts)
      {arrived_at, new_nonces}
    end

    :nonces
    |> Repo.get_and_update(fun)
    |> case do
      {arrived_at, _} -> arrived_at
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
  def save(nonce, curr_ts, config) do
    with(
      min <- ts_to_min(curr_ts, config),
      fun <- fn meta ->
        new_meta =
          meta
          |> update_count(min)
          |> update_shards(min, nonce)
          |> update_mins(min)

        {meta, new_meta}
      end,
      _ <- Repo.get_and_update(:meta, fun)
    ) do
      :ok
    end
  end

  # TODO: count is not exactly, because shards is MapSet type.
  def update_count(meta, min) do
    with(
      count <- Map.get(meta, :count),
      fun <- fn curr -> {curr, if(is_nil(curr), do: 1, else: curr + 1)} end,
      {_, new_count} <- Map.get_and_update(count, min, fun)
    ) do
      Map.put(meta, :count, new_count)
    end
  end

  def update_shards(meta, min, nonce) do
    with(
      shards <- Map.get(meta, :shards),
      fun <- fn shard ->
        new = (shard && nonce not in shard && MapSet.put(shard, nonce)) || MapSet.new([nonce])
        {shard, new}
      end,
      {_, new_shards} <- Map.get_and_update(shards, min, fun)
    ) do
      Map.put(meta, :shards, new_shards)
    end
  end

  def update_mins(meta, min) do
    with(
      mins <- Map.get(meta, :mins),
      true <- min not in mins,
      new_mins <- MapSet.put(mins, min)
    ) do
      Map.put(meta, :mins, new_mins)
    else
      false -> meta
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

  ###
  ### Use GenServer To Make Sure Operations Is Atomic.
  ###
  use GenServer

  alias ExHmac.Noncer
  alias ExHmac.Noncer.Worker

  def start_link(opts) when is_list(opts) do
    with(
      impl_m <- __MODULE__,
      repo_name <- Noncer,
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
end
