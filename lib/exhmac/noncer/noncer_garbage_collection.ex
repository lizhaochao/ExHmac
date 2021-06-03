defmodule ExHmac.Noncer.GarbageCollector do
  @moduledoc false

  alias ExHmac.{Config, Repo, Util}

  @default_search_mins_len 2

  def collect do
    with(
      precision <- Config.get_precision(),
      curr_min <- precision |> Util.get_curr_ts() |> Util.to_minute(precision),
      ttl_min <- Config.get_nonce_ttl_secs() |> Util.to_minute(:second)
    ) do
      do_collect(curr_min, ttl_min)
    end
  end

  def do_collect(curr_min, ttl_min, search_mins_len \\ @default_search_mins_len) do
    fn repo ->
      with(
        planned_mins <- make_planned_mins(curr_min, ttl_min, search_mins_len),
        %{mins: mins, shards: shards, counts: counts} <- get_meta(repo),
        {gc_nonces, gc_mins, gc_count} <- get_garbage(planned_mins, mins, shards, counts)
      ) do
        repo
        |> collect_nonces(gc_nonces)
        |> update_mins(mins, gc_mins)
        |> update_shards(shards, gc_mins)
        |> update_counts(counts, gc_mins)
        |> gc_log(gc_count, gc_mins, gc_nonces)
      end
    end
    |> Repo.update()
  end

  def get_meta(repo), do: get_in(repo, [:meta])

  def get_garbage(planned_mins, mins, shards, counts) do
    with(
      garbage_mins <- Enum.filter(planned_mins, fn planned_min -> planned_min in mins end),
      garbage_nonces <- shards |> Map.take(garbage_mins) |> Map.values() |> Enum.concat(),
      garbage_count <- counts |> Map.take(garbage_mins) |> Map.values() |> Enum.sum()
    ) do
      {garbage_nonces, garbage_mins, garbage_count}
    end
  end

  #
  def collect_nonces(repo, [_ | _] = garbage_nonces) do
    nonces = get_in(repo, [:nonces])
    new_nonces = Map.drop(nonces, garbage_nonces)
    put_in(repo, [:nonces], new_nonces)
  end

  def collect_nonces(repo, _other), do: repo

  #
  def update_mins(repo, mins, [_ | _] = garbage_mins) do
    new_mins =
      Enum.reduce(garbage_mins, mins, fn garbage_min, mins ->
        MapSet.delete(mins, garbage_min)
      end)

    put_in(repo, [:meta, :mins], new_mins)
  end

  def update_mins(repo, _mins, _other), do: repo

  #
  def update_shards(repo, shards, [_ | _] = garbage_mins) do
    new_shards = Map.drop(shards, garbage_mins)
    put_in(repo, [:meta, :shards], new_shards)
  end

  def update_shards(repo, _shards, _other), do: repo

  #
  def update_counts(repo, counts, [_ | _] = garbage_mins) do
    new_counts = Map.drop(counts, garbage_mins)
    put_in(repo, [:meta, :counts], new_counts)
  end

  def update_counts(repo, _counts, _other), do: repo

  #
  def make_planned_mins(curr_min, ttl_min, len) do
    end_min = curr_min - (ttl_min + 1)
    for(min <- (end_min - (len - 1))..end_min, do: min)
  end

  def gc_log(repo, count, mins, nonces) do
    Util.log_debug(stat: :gc, count: count, mins: mins, nonces: nonces)
    repo
  end
end
