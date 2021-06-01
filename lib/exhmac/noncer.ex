defmodule ExHmac.Noncer do
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
    fun = fn repo ->
      with(
        arrived_at <- get_in(repo, [:nonces, nonce]),
        new_repo <- put_in(repo, [:nonces, nonce], curr_ts)
      ) do
        {arrived_at, new_repo}
      end
    end

    Repo.get_and_update_nonce(fun)
  end

  def do_check(arrived_at, curr_ts, config) when is_integer(arrived_at) do
    curr_ts
    |> expired(arrived_at, config)
    |> case do
      :not_expired -> {arrived_at, :not_expired, :invalid_nonce}
      :expired -> {arrived_at, :expired, :ok}
    end
  end

  def do_check(nil = _arrived_at, _curr_ts, _config), do: {nil, :not_exists, :ok}

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
  def save_meta(raw_result, nonce, arrived_at, curr_ts, config) do
    curr_min = to_minute(curr_ts, config)
    arrived_at_min = to_minute(arrived_at, config)

    fun = fn repo ->
      repo
      |> update_mins(curr_min)
      |> update_count(curr_min, arrived_at_min, raw_result)
      |> update_shards(curr_min, arrived_at_min, nonce, raw_result)
    end

    Repo.update_meta(fun)
  end

  def update_mins(repo, curr_min) do
    with(
      mins <- get_in(repo, [:meta, :mins]),
      true <- curr_min not in mins,
      new_mins <- MapSet.put(mins, curr_min)
    ) do
      put_in(repo, [:meta, :mins], new_mins)
    else
      false -> repo
    end
  end

  #
  def update_shards(repo, curr_min, arrived_at_min, nonce, raw_result) do
    with(
      shard <- get_in(repo, [:meta, :shards, curr_min]),
      how <- how_update(curr_min, arrived_at_min, nonce, raw_result),
      _ <- delete_nonce_from_shard(repo, arrived_at_min, nonce, how)
    ) do
      cond do
        is_nil(shard) -> MapSet.new([nonce])
        not is_nil(shard) and nonce not in shard -> MapSet.put(shard, nonce)
        true -> nil
      end
      |> case do
        nil -> repo
        new_shard -> put_in(repo, [:meta, :shards, curr_min], new_shard)
      end
    end
  end

  def delete_nonce_from_shard(repo, arrived_at_min, nonce, :different_mins = _how_update) do
    shard = get_in(repo, [:meta, :shards, arrived_at_min])
    new_shard = MapSet.delete(shard, nonce)
    put_in(repo, [:meta, :count, arrived_at_min], new_shard)
  end

  def delete_nonce_from_shard(_, _, _, _), do: :ignore

  #
  def update_count(repo, curr_min, arrived_at_min, raw_result) do
    curr_min_count = get_in(repo, [:meta, :count, curr_min])
    how = how_update(curr_min_count, curr_min, arrived_at_min, raw_result)

    new_curr_min_count =
      case how do
        :init -> 1
        :in_the_same_min -> curr_min_count
        :not_exists -> curr_min_count + 1
        :different_mins -> curr_min_count + 1
      end

    minus_one(repo, arrived_at_min, how)
    put_in(repo, [:meta, :count, curr_min], new_curr_min_count)
  end

  def minus_one(repo, arrived_at_min, :different_mins = _how_update) do
    arrived_at_min_count = get_in(repo, [:meta, :count, arrived_at_min])
    put_in(repo, [:meta, :count, arrived_at_min], arrived_at_min_count - 1)
  end

  def minus_one(_, _, _), do: :ignore

  #
  def how_update(nil = _curr_min_count, _, _, _), do: :init
  def how_update(_, _, _, :not_exists = _raw_result), do: :not_exists

  def how_update(_curr_min_count, curr_min, arrived_at_min, raw_result) do
    how_update(curr_min, arrived_at_min, raw_result)
  end

  def how_update(curr_min, arrived_at_min, raw_result)
      when curr_min == arrived_at_min and raw_result in [:not_expired, :expired] do
    :in_the_same_min
  end

  def how_update(_, _, _), do: :different_mins

  def to_minute(nil = ts, _config), do: ts

  def to_minute(ts, config) do
    %{precision: precision} = config

    case precision do
      :millisecond -> ts / 1000 / 60
      _second -> ts / 60
    end
    |> trunc()
  end

  ###
  def all, do: Repo.get_all()
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
  def handle_cast({:save_meta, raw_result, nonce, arrived_at, curr_ts, config}, state) do
    Worker.save_meta(raw_result, nonce, arrived_at, curr_ts, config)
    {:noreply, state}
  end
end
