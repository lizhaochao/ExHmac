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

  def check(nonce, curr_ts, config) do
    with(
      nonces <- get_nonces(config),
      result <- do_check(nonces, nonce, curr_ts, config),
      _ <- save(nonces, nonce, curr_ts, config)
    ) do
      result
    end
  end

  def get_nonces(config) do
    :nonces
    |> Repo.get(config)
    |> case do
      {:ok, nonces} -> nonces
      err -> do_throw(err)
    end
  end

  def do_check(nonces, nonce, curr_ts, config) do
    with(
      arrived_at when is_integer(arrived_at) <- Map.get(nonces, nonce, :not_exists),
      :not_expired <- expired(curr_ts, arrived_at, config)
    ) do
      :invalid_nonce
    else
      :not_exists -> :ok
      :expired -> :ok
    end
  end

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
  def save(nonces, nonce, curr_ts, config) do
    with(
      :ok <- update_nonces(nonces, nonce, curr_ts, config),
      min_ts <- ts_to_min(curr_ts, config),
      :ok <- update_count(min_ts, config),
      :ok <- update_shards(min_ts, nonce, config),
      :ok <- update_mins(curr_ts, config)
    ) do
      :ok
    end
  end

  def update_nonces(nonces, nonce, curr_ts, config) do
    with(
      new_nonces <- Map.put(nonces, nonce, curr_ts),
      :ok = result <- Repo.update(:nonces, new_nonces, config)
    ) do
      result
    else
      err -> do_throw(err)
    end
  end

  def update_mins(curr_ts, config) do
    with(
      min_ts <- ts_to_min(curr_ts, config),
      {:ok, mins} <- Repo.get(:mins, config),
      latest_min <- List.first(mins),
      true <- latest_min != min_ts,
      new_mins <- (latest_min && [min_ts | mins]) || [min_ts],
      :ok = result <- Repo.update(:mins, new_mins, config)
    ) do
      result
    else
      false -> :ignore
      err -> do_throw(err)
    end
  end

  def update_shards(min, nonce, config) do
    with(
      {:ok, shards} <- Repo.get(:shards, config),
      fun <- fn curr -> {curr, (curr && [nonce | curr]) || [nonce]} end,
      {_, new_shards} <- Map.get_and_update(shards, min, fun),
      :ok = result <- Repo.update(:shards, new_shards, config)
    ) do
      result
    else
      err -> do_throw(err)
    end
  end

  def update_count(min, config) do
    with(
      {:ok, cnt} <- Repo.get(:count, config),
      fun <- fn curr -> {curr, if(is_nil(curr), do: 1, else: curr + 1)} end,
      {_, new_cnt} <- Map.get_and_update(cnt, min, fun),
      :ok = result <- Repo.update(:count, new_cnt, config)
    ) do
      result
    else
      err -> do_throw(err)
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

  def do_throw(msg), do: throw("Repo Unavailable: #{msg}")

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
    with impl_m <- __MODULE__,
         repo_name <- Noncer,
         name_opt <- [name: repo_name] do
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
