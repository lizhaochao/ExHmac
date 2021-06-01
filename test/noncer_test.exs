defmodule NoncerTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer.Worker

  @prec :millisecond
  @config [] |> Config.get_config() |> Map.put(:precision, @prec)

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
    test_fun = fn n, curr_ts -> Noncer.save_meta_cast(n, curr_ts, @config) end
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
        arrived_at <- :not_exists
      ) do
        assert :ok == Worker.do_check(arrived_at, curr_ts, @config)
      end
    end

    test "ok - expired" do
      with(
        %{nonce_ttl: ttl} <- @config,
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - ttl
      ) do
        assert :ok == Worker.do_check(arrived_at, curr_ts, @config)
      end
    end

    test "invalid nonce - not expired" do
      with(
        %{nonce_ttl: ttl} <- @config,
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - ttl + 10
      ) do
        assert :invalid_nonce == Worker.do_check(arrived_at, curr_ts, @config)
      end
    end
  end
end
