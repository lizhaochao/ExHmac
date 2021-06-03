defmodule PerformanceTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer, Repo, Util}
  alias ExHmac.Noncer.GarbageCollector, as: GC

  @ttl Config.get_nonce_ttl_secs()
  @precision :millisecond

  setup_all do
    Repo.reinit()
    :ok
  end

  @tag :performance
  test "check/4" do
    target_n = 60_000
    test_fun = fn n, curr_ts -> Noncer.check(n, curr_ts, @ttl, @precision) end
    run_with_n(test_fun, target_n)
  end

  @tag :performance
  test "save_meta/5" do
    target_n = 60_000
    test_fun = fn n, curr_ts -> Noncer.save_meta(:not_exists, n, nil, curr_ts, @precision) end
    run_with_n(test_fun, target_n)

    %{counts: counts} = Noncer.all() |> Map.get(:meta)
    assert target_n == Enum.sum(Map.values(counts))
  end

  @tag :performance
  test "collect/0" do
    curr_ts = get_curr_ts(@precision)
    records = 10000

    1..records
    |> Enum.each(fn n ->
      Noncer.save_meta(:not_exists, n, nil, curr_ts, @precision)
    end)

    curr_min = Util.to_minute(curr_ts, @precision)
    ttl_min = Util.to_minute(@ttl, @precision)
    target_n = 55_000
    test_fun = fn _, _ -> GC.do_collect(curr_min, ttl_min) end
    run_with_n(test_fun, target_n)
    Noncer.all() |> Map.get(:meta)

    %{counts: counts} = Noncer.all() |> Map.get(:meta)
    assert records == Enum.sum(Map.values(counts))
  end

  ###
  def check_sync(nonce, curr_ts) do
    {arrived_at, raw_result, _} = Noncer.check(nonce, curr_ts, @ttl, @precision)
    Noncer.save_meta(raw_result, nonce, arrived_at, curr_ts, @precision)
    raw_result
  end

  def run_with_n(fun, times \\ 10_000, timeout \\ 30_000) do
    with(
      start_time <- get_curr_ts(@precision),
      curr_ts <- start_time,
      tasks <- Enum.map(1..times, fn n -> Task.async(fn -> fun.(n, curr_ts) end) end),
      _ <- Task.await_many(tasks, timeout),
      end_time <- get_curr_ts(@precision),
      diff <- end_time - start_time,
      expected_max_spent_milli <- 1000
    ) do
      assert diff <= expected_max_spent_milli
    end
  end

  def get_curr_ts(precision \\ :second), do: DateTime.utc_now() |> DateTime.to_unix(precision)
end
