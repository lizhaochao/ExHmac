defmodule NoncerTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer.Worker
  alias ExHmac.Repo

  setup_all do
    Repo.reinit()
    :ok
  end

  @prec :millisecond
  @config [] |> Config.get_config() |> Map.put(:precision, @prec)

  describe "renew nonce arrived_at" do
    test "not exists -> not expired -> expired with same nonce" do
      with(
        %{nonce_ttl: ttl_secs} <- @config,
        nonce <- "A1B2C3",
        # first
        curr_ts1 <- get_curr_ts(),
        _ <- Noncer.check(nonce, curr_ts1, @config),
        # second
        curr_ts2 <- curr_ts1 + (ttl_secs - 20) * 1000,
        _ <- Noncer.check(nonce, curr_ts2, @config),
        # third
        curr_ts3 <- curr_ts2 + ttl_secs * 2 * 1000,
        _ <- Noncer.check(nonce, curr_ts3, @config)
      ) do
        ##  Repo SnapShoot
        ##  %{
        ##    meta: %{
        ##      count: %{27_042_870 => 0, 27_042_885 => 0, 27_042_900 => 1},
        ##      mins: #MapSet<[27042870, 27042885, 27042900]>,
        ##      shards: %{
        ##        27_042_870 => #MapSet<[]>,
        ##        27_042_885 => #MapSet<[]>,
        ##        27_042_900 => #MapSet<["A1B2C3"]>
        ##      }
        ##    },
        ##    nonces: %{"A1B2C3" => 1_622_574_051_220}
        ##  }

        %{nonces: nonces, meta: %{shards: shards, mins: mins, count: count}} = Worker.all()
        assert 1 == length(Map.keys(nonces))
        assert 1 == Enum.sum(Map.values(count))
        assert 3 == length(MapSet.to_list(mins))

        to_list_fum = fn shard -> MapSet.to_list(shard) end
        assert 1 == length(List.flatten(Enum.map(Map.values(shards), to_list_fum)))
      end
    end
  end

  @tag :noncer
  @tag timeout: 120_000
  test "ExHmac.Noncer.check/3" do
    test_fun = fn n, curr_ts -> Noncer.check(n, curr_ts, @config) end
    run_n_times(test_fun)
    Worker.all() |> Map.get(:meta)
  end

  @tag :noncer
  @tag timeout: 120_000
  test "ExHmac.Noncer.save_meta_cast/3" do
    test_fun = fn n, curr_ts -> Noncer.save_meta_call(:ok, n, curr_ts - 10, curr_ts, @config) end
    run_n_times(test_fun)
    Worker.all() |> Map.get(:meta)
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

  def get_curr_ts, do: DateTime.utc_now() |> DateTime.to_unix(@prec)
end

defmodule NoncerWorkerTest do
  use ExUnit.Case

  alias ExHmac.Config
  alias ExHmac.Noncer.Worker

  @config Config.get_config([])

  describe "do_check/4" do
    test "ok - not exists" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- nil
      ) do
        assert {nil, :not_exists, :ok} == Worker.do_check(arrived_at, curr_ts, @config)
      end
    end

    test "ok - expired" do
      with(
        %{nonce_ttl: ttl} <- @config,
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - ttl
      ) do
        assert {arrived_at, :expired, :ok} == Worker.do_check(arrived_at, curr_ts, @config)
      end
    end

    test "invalid nonce - not expired" do
      with(
        %{nonce_ttl: ttl} <- @config,
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - ttl + 10
      ) do
        assert {arrived_at, :not_expired, :invalid_nonce} ==
                 Worker.do_check(arrived_at, curr_ts, @config)
      end
    end
  end
end
