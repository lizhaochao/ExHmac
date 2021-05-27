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

  describe "warn_offset/4" do
    test "should_warn" do
      with radio <- 0.01,
           curr_ts <- 100 do
        assert :should_warn == Checker.warn_offset(curr_ts, 100_500, radio, true)
        assert :should_warn == Checker.warn_offset(curr_ts, 100_000, radio, true)
        assert :should_warn == Checker.warn_offset(curr_ts, 99_500, radio, true)
      end
    end

    test "ignore" do
      with any_radio <- 0.01,
           any_curr_ts <- 100,
           any_ts <- 101 do
        assert :ignore == Checker.warn_offset(any_curr_ts, any_ts, any_radio, false)
      end
    end
  end

  ### check_nonce
  describe "do_check_nonce/3" do
    test "ok" do
      with curr_ts <- 100,
           ttl <- 20 do
        assert :ok == Checker.do_check_nonce(curr_ts, nil, ttl)
        assert :ok == Checker.do_check_nonce(curr_ts, 79, ttl)
      end
    end

    test "error" do
      with curr_ts <- 100,
           ttl <- 20 do
        assert :invalid_nonce == Checker.do_check_nonce(curr_ts, 80, ttl)
        assert :invalid_nonce == Checker.do_check_nonce(curr_ts, 120, ttl)
      end
    end
  end

  describe "get_created_at/1" do
    test "ok" do
      assert {:ok, nil} == Checker.get_created_at("a7b801")
    end
  end

  describe "get_curr_ts 0/1" do
    test "second" do
      with up_to_2050 <- 2_524_579_200,
           curr <- 1_622_118_000,
           result1 <- Checker.get_curr_ts(),
           result2 <- Checker.get_curr_ts(:second) do
        assert up_to_2050 > result1
        assert result1 > curr

        assert up_to_2050 > result2
        assert result2 > curr
      end
    end

    test "millisecond" do
      with up_to_2050 <- 2_524_579_200_000,
           curr <- 1_622_118_000_000,
           result <- Checker.get_curr_ts(:millisecond) do
        assert up_to_2050 > result
        assert result > curr
      end
    end
  end

  ###
  describe "raise error" do
    test "check_timestamp/3 error" do
      [
        {"123", ":millisecond", "true"},
        {"123", :millisecond, true},
        {1_622_115_000, ":millisecond", true},
        {1_622_115_000, :millisecond, "true"}
      ]
      |> Enum.each(fn {ts, precision, warn} ->
        assert_raise Error, fn ->
          Checker.check_timestamp(ts, precision, warn)
        end
      end)
    end

    test "check_nonce/3 error" do
      [1, 1.1, :ok, %{}, [], {}, 1..2, fn -> nil end]
      |> Enum.each(fn nonce ->
        assert_raise Error, fn ->
          Checker.check_nonce(nonce)
        end
      end)
    end
  end
end
