defmodule NoncerTest do
  use ExUnit.Case

  alias ExHmac.Config
  alias ExHmac.Noncer.Worker

  @config Config.get_config([])

  describe "do_check/4" do
    test "ok - not exists" do
      with(
        curr_ts <- 1_622_474_344,
        nonces <- %{},
        nonce <- "A1B2C3"
      ) do
        assert :ok == Worker.do_check(nonces, nonce, curr_ts, @config)
      end
    end

    test "ok - expired" do
      with(
        %{nonce_ttl: ttl} <- @config,
        curr_ts <- 1_622_474_344,
        nonces <- %{"A1B2C3" => curr_ts - ttl},
        nonce <- "A1B2C3"
      ) do
        assert :ok == Worker.do_check(nonces, nonce, curr_ts, @config)
      end
    end

    test "invalid nonce - not expired" do
      with(
        %{nonce_ttl: ttl} <- @config,
        curr_ts <- 1_622_474_344,
        nonces <- %{"A1B2C3" => curr_ts - ttl + 10},
        nonce <- "A1B2C3"
      ) do
        assert :invalid_nonce == Worker.do_check(nonces, nonce, curr_ts, @config)
      end
    end
  end
end
