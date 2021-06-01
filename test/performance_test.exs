defmodule PerformanceTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer.Worker

  @precision :millisecond
  @config [] |> Config.get_config() |> Map.put(:precision, @precision)

  @tag :performance
  @tag timeout: 120_000
  test "ExHmac.Noncer.check/3" do
    with(
      times <- 2500,
      start_time <- get_curr_ts(),
      curr_ts <- start_time,
      tasks <-
        Enum.map(1..times, fn n ->
          Task.async(fn -> Noncer.check(n, curr_ts, @config) end)
        end),
      timeout <- 20_000,
      _ <- Task.await_many(tasks, timeout),
      end_time <- get_curr_ts(),
      expected_max_spent_milli <- 1000,
      diff <- end_time - start_time
    ) do
      assert diff < expected_max_spent_milli
    end
  end

  @tag :performance
  @tag timeout: 120_000
  test "ExHmac.Noncer.Worker.save/3" do
    with(
      times <- 5000,
      start_time <- get_curr_ts(),
      curr_ts <- start_time,
      tasks <-
        Enum.map(1..times, fn n ->
          Task.async(fn -> Worker.save(n, curr_ts, @config) end)
        end),
      timeout <- 20_000,
      _ <- Task.await_many(tasks, timeout),
      end_time <- get_curr_ts(),
      expected_max_spent_milli <- 1000,
      diff <- end_time - start_time
    ) do
      assert diff < expected_max_spent_milli
    end
  end

  ###
  def get_curr_ts, do: DateTime.utc_now() |> DateTime.to_unix(@precision)
end
