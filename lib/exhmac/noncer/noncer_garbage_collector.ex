defmodule ExHmac.Noncer.GarbageCollector do
  @moduledoc false

  alias ExHmac.{Config, Repo, Util}

  @default_search_mins_len Config.get_search_mins_len()
  @gc_warn_count Config.get_gc_warn_count()

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
        |> drop_nonces(gc_nonces)
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
      [_ | _] = garbage_mins <- Enum.filter(planned_mins, fn min -> min in mins end),
      garbage_nonces <- shards |> Map.take(garbage_mins) |> Map.values() |> Enum.concat(),
      garbage_count <- counts |> Map.take(garbage_mins) |> Map.values() |> Enum.sum()
    ) do
      {garbage_nonces, garbage_mins, garbage_count}
    else
      [] = _garbage_mins -> {[], [], 0}
    end
  end

  #
  def drop_nonces(repo, [_ | _] = garbage_nonces) do
    nonces = get_in(repo, [:nonces])
    new_nonces = Map.drop(nonces, garbage_nonces)
    put_in(repo, [:nonces], new_nonces)
  end

  def drop_nonces(repo, _other), do: repo

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
    with(
      end_min <- curr_min - (ttl_min + 1),
      planned_mins <- for(min <- (end_min - (len - 1))..end_min, do: min),
      log_content <- [gc: :info, planned_mins: planned_mins, ttl_min: ttl_min],
      _ <- Util.log(:debug, log_content, &log_color/2)
    ) do
      planned_mins
    end
  end

  ###
  def gc_log(repo, count, [_ | _] = mins, [_ | _] = nonces) when count > 0 do
    with(
      content <- [gc: :stat, count: count, mins: mins, nonces: nonces],
      level <- if(count > @gc_warn_count, do: :warn, else: :debug),
      _ <- Util.log(level, content, &log_color/2)
    ) do
      repo
    end
  end

  def gc_log(repo, _other_count, _other_mins, _other_nonces), do: repo

  def log_color(:debug, {:gc, :info}), do: :white
  def log_color(:debug, {:gc, :stat}), do: :yellow
  def log_color(:warn, {:gc, :stat}), do: :red
  def log_color(_, _), do: :cyan
end
