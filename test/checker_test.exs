defmodule CheckerTest do
  use ExUnit.Case

  alias ExHmac.{Checker, Error}

  ### check_timestamp
  describe "do_check_timestamp/3" do
    test "ok" do
      with offset <- 20 do
        assert :ok == Checker.do_check_timestamp(100, 90, offset)
        assert :ok == Checker.do_check_timestamp(90, 100, offset)
      end
    end

    test "error" do
      with offset <- 20 do
        assert :timestamp_out_of_range == Checker.do_check_timestamp(100, 80, offset)
        assert :timestamp_out_of_range == Checker.do_check_timestamp(80, 100, offset)
      end
    end
  end

  describe "get_offset/2" do
    test "expected precisions" do
      with default <- 1000 do
        assert default * 1000 == Checker.get_offset(:millisecond, default)
        assert default == Checker.get_offset(:second, default)
      end
    end

    test "other precision" do
      with default <- 1000 do
        assert default == Checker.get_offset(:other, default)
      end
    end
  end

  describe "do_warn_offset/4" do
    test "should_warn" do
      with ratio <- 0.01,
           curr_ts <- 100 do
        assert :should_warn == Checker.do_warn_offset(curr_ts, 100_500, ratio)
        assert :should_warn == Checker.do_warn_offset(curr_ts, 100_000, ratio)
        assert :should_warn == Checker.do_warn_offset(curr_ts, 99_500, ratio)
      end
    end

    test "ignore" do
      with any_ratio <- 0.01,
           any_curr_ts <- 100,
           any_ts <- 101 do
        assert :ignore == Checker.do_warn_offset(any_curr_ts, any_ts, any_ratio)
      end
    end
  end

  ###
  describe "raise error" do
    test "check_timestamp/4 error" do
      [
        {1_622_115_000, []},
        {"123", %{}}
      ]
      |> Enum.each(fn {ts, config} ->
        assert_raise Error, fn ->
          Checker.check_timestamp(ts, config)
        end
      end)
    end

    test "check_nonce/1 error" do
      [1, 1.1, %{}, [], true, {}, 1..2]
      |> Enum.each(fn nonce ->
        assert_raise Error, fn ->
          Checker.check_nonce(nonce)
        end
      end)
    end
  end
end
