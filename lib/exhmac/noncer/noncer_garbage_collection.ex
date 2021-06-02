defmodule ExHmac.Noncer.GarbageCollection do
  @moduledoc false

  alias ExHmac.{Config, Repo, Util}

  @search_mins_len 1

  def collect do
    with(
      precision <- Config.get_precision(),
      curr_min <- precision |> Util.get_curr_ts() |> Util.to_minute(precision),
      ttl_min <- Config.get_nonce_ttl_secs() |> Util.to_minute(:second)
    ) do
      do_collect(curr_min, ttl_min, @search_mins_len)
    end
  end

  def do_collect(curr_min, ttl_min, search_mins_len \\ 1) do
    fn repo ->
      with(
        end_min <- curr_min - (ttl_min + 1),
        planned_mins <- make_planned_mins(end_min, search_mins_len),
        mins <- get_in(repo, [:meta, :mins]),
        shards <- get_in(repo, [:meta, :shards]),
        counts <- get_in(repo, [:meta, :counts]),
        exists_mins <- Enum.filter(planned_mins, fn planned_min -> planned_min in mins end),
        collect_nonces <- shards |> Map.take(exists_mins) |> Map.values() |> Enum.concat(),
        collect_count <- counts |> Map.take(exists_mins) |> Map.values() |> Enum.sum()
      ) do
        repo
        |> update_nonces(collect_nonces)
        |> update_mins(mins, exists_mins)
        |> update_shards(shards, exists_mins)
        |> update_counts(counts, exists_mins)
        |> gc_log(collect_count, exists_mins, collect_nonces)
      end
    end
    |> Repo.update()
  end

  #
  def update_nonces(repo, [_ | _] = collect_nonces) do
    nonces = get_in(repo, [:nonces])
    new_nonces = Map.drop(nonces, collect_nonces)
    put_in(repo, [:nonces], new_nonces)
  end

  def update_nonces(repo, _collect_nonces), do: repo

  #
  def update_mins(repo, mins, [_ | _] = exists_mins) do
    new_mins =
      Enum.reduce(exists_mins, mins, fn exists_min, mins ->
        MapSet.delete(mins, exists_min)
      end)

    put_in(repo, [:meta, :mins], new_mins)
  end

  def update_mins(repo, _mins, _other_exists_mins), do: repo

  #
  def update_shards(repo, shards, [_ | _] = exists_mins) do
    new_shards = Map.drop(shards, exists_mins)
    put_in(repo, [:meta, :shards], new_shards)
  end

  def update_shards(repo, _shards, _other_exists_mins), do: repo

  #
  def update_counts(repo, counts, [_ | _] = exists_mins) do
    new_counts = Map.drop(counts, exists_mins)
    put_in(repo, [:meta, :counts], new_counts)
  end

  def update_counts(repo, _other_exists_mins), do: repo

  #
  def make_planned_mins(end_min, len), do: for(min <- (end_min - len)..end_min, do: min)

  def gc_log(repo, count, mins, nonces) do
    Util.log_debug(title: :gc_stat, count: count, mins: mins, nonces: nonces)
    repo
  end
end
