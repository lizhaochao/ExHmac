defmodule NoncerTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer
  alias ExHmac.Noncer.Client, as: NoncerClient
  alias ExHmac.Repo

  setup_all do
    Repo.reinit()
    :ok
  end

  @ttl Config.get_nonce_ttl_secs()
  @precision :millisecond

  describe "renew nonce arrived_at" do
    test "not exists -> not expired -> expired with same nonce" do
      ttl_secs = Config.get_nonce_ttl_secs()
      nonce = "A1B2C3"
      # first
      curr_ts1 = get_curr_ts()
      NoncerClient.check(nonce, curr_ts1, @ttl, @precision)
      # second
      curr_ts2 = curr_ts1 + (ttl_secs - 20) * 1000
      NoncerClient.check(nonce, curr_ts2, @ttl, @precision)
      # third
      curr_ts3 = curr_ts2 + ttl_secs * 2 * 1000
      NoncerClient.check(nonce, curr_ts3, @ttl, @precision)

      # await is not really work for this situation.
      # fn -> want_run_fun.() end |> Task.async() |> Task.await()
      # so just sleep a little milliseconds.
      Process.sleep(10)

      %{nonces: nonces, meta: %{shards: shards, mins: mins, counts: counts}} = Noncer.all()
      assert 1 == length(Map.keys(nonces))
      assert 1 == Enum.sum(Map.values(counts))
      assert 3 == length(MapSet.to_list(mins))

      to_list_fum = fn shard -> MapSet.to_list(shard) end
      assert 1 == length(List.flatten(Enum.map(Map.values(shards), to_list_fum)))
    end
  end

  @tag :noncer
  @tag timeout: 120_000
  test "check_call/3" do
    test_fun = fn n, curr_ts -> NoncerClient.check_call(n, curr_ts, @ttl, @precision) end
    run_n_times(test_fun)
    Noncer.all() |> Map.get(:meta)
  end

  @tag :noncer
  @tag timeout: 120_000
  test "save_meta_cast/3" do
    test_fun = fn n, curr_ts ->
      NoncerClient.save_meta_cast(:ok, n, curr_ts - 10, curr_ts, @precision)
    end

    run_n_times(test_fun)
    Noncer.all() |> Map.get(:meta)
  end

  ###
  def run_n_times(fun, times \\ 10_000, timeout \\ 30_000) do
    with(
      start_time <- get_curr_ts(),
      curr_ts <- start_time,
      tasks <- Enum.map(1..times, fn n -> Task.async(fn -> fun.(n, curr_ts) end) end),
      _ <- Task.await_many(tasks, timeout),
      end_time <- get_curr_ts(),
      diff <- end_time - start_time,
      expected_max_spent_milli <- 1000
    ) do
      assert diff < expected_max_spent_milli
    end
  end

  def get_curr_ts, do: DateTime.utc_now() |> DateTime.to_unix(@precision)
end

defmodule NoncerWorkerTest do
  use ExUnit.Case

  alias ExHmac.Config
  alias ExHmac.Noncer

  @ttl Config.get_nonce_ttl_secs()
  @precision Config.get_precision()

  describe "do_check/4" do
    test "ok - not exists" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- nil
      ) do
        assert {nil, :not_exists, :ok} == Noncer.do_check(arrived_at, curr_ts, @ttl, @precision)
      end
    end

    test "ok - expired" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - @ttl
      ) do
        assert {arrived_at, :expired, :ok} ==
                 Noncer.do_check(arrived_at, curr_ts, @ttl, @precision)
      end
    end

    test "invalid nonce - not expired" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - @ttl + 10
      ) do
        assert {arrived_at, :not_expired, :invalid_nonce} ==
                 Noncer.do_check(arrived_at, curr_ts, @ttl, @precision)
      end
    end
  end
end
