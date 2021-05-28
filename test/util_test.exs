defmodule UtilTest do
  use ExUnit.Case

  alias ExHmac.Util

  describe "get_curr_ts 0/1" do
    test "second" do
      with up_to_2050 <- 2_524_579_200,
           curr <- 1_622_118_000,
           result1 <- Util.get_curr_ts(),
           result2 <- Util.get_curr_ts(:second) do
        assert up_to_2050 > result1
        assert result1 > curr

        assert up_to_2050 > result2
        assert result2 > curr
      end
    end

    test "millisecond" do
      with up_to_2050 <- 2_524_579_200_000,
           curr <- 1_622_118_000_000,
           result <- Util.get_curr_ts(:millisecond) do
        assert up_to_2050 > result
        assert result > curr
      end
    end
  end
end
