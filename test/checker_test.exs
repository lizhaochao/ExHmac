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
        assert :should_warn == Checker.do_warn_offset(curr_ts, 100_500, ratio, true)
        assert :should_warn == Checker.do_warn_offset(curr_ts, 100_000, ratio, true)
        assert :should_warn == Checker.do_warn_offset(curr_ts, 99_500, ratio, true)
      end
    end

    test "ignore" do
      with any_ratio <- 0.01,
           any_curr_ts <- 100,
           any_ts <- 101 do
        assert :ignore == Checker.do_warn_offset(any_curr_ts, any_ts, any_ratio, false)
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

  ###
  describe "raise error" do
    test "check_timestamp/4 error" do
      [
        {1_622_115_000, []},
        {"123", %{}}
      ]
      |> Enum.each(fn {ts, opts} ->
        assert_raise Error, fn ->
          Checker.check_timestamp(ts, opts)
        end
      end)
    end

    test "check_nonce/2 error" do
      [
        {1, []},
        {123, %{}},
        {"a1h801", []}
      ]
      |> Enum.each(fn {nonce, opts} ->
        assert_raise Error, fn ->
          Checker.check_nonce(nonce, opts)
        end
      end)
    end

    test "check_nonce/2 opts error" do
      assert_raise Error, fn ->
        Checker.check_nonce("a1k8h1", %{b: 2})
      end
    end
  end
end
