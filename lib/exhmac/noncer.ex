defmodule ExHmac.Noncer do
  @moduledoc false

  alias ExHmac.Noncer.Server

  ### Client
  def check(nonce, curr_ts, config) do
    with(
      {arrived_at, raw_result, result} <- check_call(nonce, curr_ts, config),
      _ <- save_meta_call(raw_result, nonce, arrived_at, curr_ts, config)
    ) do
      result
    end
  end

  def check_call(nonce, curr_ts, config) do
    GenServer.call(Server, {nonce, curr_ts, config})
  end

  def save_meta_call(raw_result, nonce, arrived_at, curr_ts, config) do
    GenServer.call(Server, {:save_meta, raw_result, nonce, arrived_at, curr_ts, config})
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
      %{nonce_ttl: ttl, precision: precision} <- config,
      diff <- curr_ts - arrived_at
    ) do
      precision
      |> case do
        :millisecond -> trunc(diff / 1000)
        _second -> diff
      end
      |> Kernel.>=(ttl)
      |> if(
        do: :expired,
        else: :not_expired
      )
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
  def update_count(repo, curr_min, arrived_at_min, raw_result) do
    curr_min_count = get_in(repo, [:meta, :count, curr_min])
    curr_min_count = (curr_min_count && curr_min_count + 1) || 1
    how = in_same_min(curr_min, arrived_at_min, raw_result)

    new_curr_min_count =
      if how == :same_min and curr_min_count > 1 do
        curr_min_count - 1
      else
        curr_min_count
      end

    repo = put_in(repo, [:meta, :count, curr_min], new_curr_min_count)
    minus_one(repo, arrived_at_min, how)
  end

  def minus_one(repo, arrived_at_min, :different_mins = _how_update)
      when not is_nil(arrived_at_min) do
    old = get_in(repo, [:meta, :count, arrived_at_min])
    new = old && old - 1
    put_in(repo, [:meta, :count, arrived_at_min], new)
  end

  def minus_one(repo, _, _), do: repo

  #
  def update_shards(repo, curr_min, arrived_at_min, nonce, raw_result) do
    with(
      shard <- get_in(repo, [:meta, :shards, curr_min]),
      how <- in_same_min(curr_min, arrived_at_min, raw_result),
      repo <- delete_nonce_from_shard(repo, arrived_at_min, nonce, how)
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

  def delete_nonce_from_shard(repo, arrived_at_min, nonce, :different_mins = _how_update)
      when not is_nil(arrived_at_min) do
    old = get_in(repo, [:meta, :shards, arrived_at_min])
    new = old && MapSet.delete(old, nonce)
    put_in(repo, [:meta, :shards, arrived_at_min], new)
  end

  def delete_nonce_from_shard(repo, _, _, _), do: repo

  #
  def in_same_min(_, _, raw_result) when raw_result not in [:not_expired, :expired], do: :error
  def in_same_min(curr_min, arrived_at_min, _) when curr_min == arrived_at_min, do: :same_min
  def in_same_min(_, _, _), do: :different_mins

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
  def handle_call({:save_meta, raw_result, nonce, arrived_at, curr_ts, config}, _from, state) do
    Worker.save_meta(raw_result, nonce, arrived_at, curr_ts, config)
    {:reply, nil, state}
  end
end
