defmodule PerformanceTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer.Worker

  @config Config.get_config([])

  # TODO: test without gen timestamp & gen nonce tests
  # TODO: test with many prepared nonces

  @tag :performance
  test "Noncer.check/3" do
    with(
      start_time <- get_curr_ts(),
      times <- 50_000,
      nonce <- "a1b2c3",
      curr_ts <- 1_622_523_551,
      tasks <-
        Enum.map(1..times, fn _ ->
          Task.async(fn -> Noncer.check(nonce, curr_ts, @config) end)
        end),
      timeout <- 20_000,
      _ <- Task.await_many(tasks, timeout),
      end_time <- get_curr_ts(),
      expected_max_spent_milli <- 1000
    ) do
      assert end_time - start_time < expected_max_spent_milli
    end
  end

  test "ExHmac.Noncer.Worker.save/3" do
    with(
      start_time <- get_curr_ts(),
      times <- 35_000,
      nonce <- "a1b2c3",
      curr_ts <- 1_622_523_551,
      tasks <-
        Enum.map(1..times, fn _ ->
          Task.async(fn -> Worker.save(nonce, curr_ts, @config) end)
        end),
      timeout <- 20_000,
      _ <- Task.await_many(tasks, timeout),
      end_time <- get_curr_ts(),
      expected_max_spent_milli <- 1000
    ) do
      assert end_time - start_time < expected_max_spent_milli
    end
  end

  ###
  def get_curr_ts, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
end
