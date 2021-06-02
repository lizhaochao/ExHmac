defmodule ExHmac.Noncer do
  @moduledoc false

  alias ExHmac.{Repo, Util}

  ###
  def check(nonce, curr_ts, ttl, precision) do
    nonce
    |> get_and_update_nonce(curr_ts)
    |> do_check(curr_ts, ttl, precision)
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

    Repo.get(fun)
  end

  def do_check(arrived_at, curr_ts, ttl, precision) when is_integer(arrived_at) do
    curr_ts
    |> expired(arrived_at, ttl, precision)
    |> case do
      :not_expired -> {arrived_at, :not_expired, :invalid_nonce}
      :expired -> {arrived_at, :expired, :ok}
    end
  end

  def do_check(nil = _arrived_at, _curr_ts, _ttl, _precision), do: {nil, :not_exists, :ok}

  def expired(curr_ts, arrived_at, ttl, precision) do
    diff = curr_ts - arrived_at

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

  ###
  def save_meta(raw_result, nonce, arrived_at, curr_ts, precision) do
    curr_min = Util.to_minute(curr_ts, precision)
    arrived_at_min = Util.to_minute(arrived_at, precision)

    fun = fn repo ->
      repo
      |> update_mins(curr_min)
      |> update_counts(curr_min, arrived_at_min, raw_result)
      |> update_shards(curr_min, arrived_at_min, nonce, raw_result)
    end

    Repo.update(fun)
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

  def update_counts(repo, curr_min, arrived_at_min, raw_result) do
    curr_min_counts = get_in(repo, [:meta, :counts, curr_min])
    curr_min_counts = (curr_min_counts && curr_min_counts + 1) || 1
    in_same_shard = in_same_shard(curr_min, arrived_at_min, raw_result)

    new_curr_min_counts =
      if in_same_shard == :same_shard and curr_min_counts > 1 do
        curr_min_counts - 1
      else
        curr_min_counts
      end

    repo = put_in(repo, [:meta, :counts, curr_min], new_curr_min_counts)
    minus_one(repo, arrived_at_min, in_same_shard)
  end

  def minus_one(repo, arrived_at_min, :different_shards = _in_same_shard)
      when not is_nil(arrived_at_min) do
    old = get_in(repo, [:meta, :counts, arrived_at_min])
    new = old && old - 1
    put_in(repo, [:meta, :counts, arrived_at_min], new)
  end

  def minus_one(repo, _, _), do: repo

  def update_shards(repo, curr_min, arrived_at_min, nonce, raw_result) do
    with(
      shard <- get_in(repo, [:meta, :shards, curr_min]),
      in_same_shard <- in_same_shard(curr_min, arrived_at_min, raw_result),
      repo <- delete_nonce_from_shard(repo, arrived_at_min, nonce, in_same_shard)
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

  def delete_nonce_from_shard(repo, arrived_at_min, nonce, :different_shards)
      when not is_nil(arrived_at_min) do
    old = get_in(repo, [:meta, :shards, arrived_at_min])
    new = old && MapSet.delete(old, nonce)
    put_in(repo, [:meta, :shards, arrived_at_min], new)
  end

  def delete_nonce_from_shard(repo, _, _, _), do: repo

  def in_same_shard(_, _, raw_result) when raw_result not in [:not_expired, :expired], do: :error
  def in_same_shard(curr_min, arrived_at_min, _) when curr_min == arrived_at_min, do: :same_shard
  def in_same_shard(_, _, _), do: :different_shards

  ###
  def all, do: Repo.get_all()

  ###
  def gen_nonce(len), do: gen_random(trunc(len / 2))
  defp gen_random(bits), do: bits |> :crypto.strong_rand_bytes() |> Base.encode16()
end
