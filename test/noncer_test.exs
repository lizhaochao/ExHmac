defmodule NoncerTest do
  use ExUnit.Case

  alias ExHmac.{Config, Noncer}
  alias ExHmac.Noncer
  alias ExHmac.Repo

  setup_all do
    Repo.init()
    :ok
  end

  @nonce_freezing_secs Config.get_nonce_freezing_secs()
  @precision :millisecond

  test "renew nonce arrived_at" do
    nonce = "A1B2C3"
    # 1
    curr_ts1 = get_curr_ts(@precision)
    assert :not_exists == check_sync(nonce, curr_ts1)
    # 2
    curr_ts2 = curr_ts1 + (@nonce_freezing_secs - 1) * 1000
    assert :freezing == check_sync(nonce, curr_ts2)
    # 3
    curr_ts3 = curr_ts2 + (@nonce_freezing_secs - 1) * 1000
    assert :freezing == check_sync(nonce, curr_ts3)
    # 4
    curr_ts4 = curr_ts3 + (@nonce_freezing_secs + 1) * 1000
    assert :not_freezing == check_sync(nonce, curr_ts4)

    %{nonces: nonces, meta: %{shards: shards, mins: mins, counts: counts}} = Noncer.all()
    assert 1 == length(Map.keys(nonces))
    assert 1 == Enum.sum(Map.values(counts))
    assert 3 == map_size(mins)
    assert 1 == length(Enum.concat(Map.values(shards)))
  end

  def check_sync(nonce, curr_ts) do
    {arrived_at, raw_result, _} = Noncer.check(nonce, curr_ts, @nonce_freezing_secs, @precision)
    Noncer.save_meta(raw_result, nonce, arrived_at, curr_ts, @precision)
    raw_result
  end

  def get_curr_ts(precision \\ :second), do: DateTime.utc_now() |> DateTime.to_unix(precision)
end

defmodule NoncerWorkerTest do
  use ExUnit.Case

  alias ExHmac.Config
  alias ExHmac.Noncer

  @nonce_freezing_secs Config.get_nonce_freezing_secs()
  @precision Config.get_precision()

  describe "do_check/4" do
    test "ok - not exists" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- nil
      ) do
        assert {nil, :not_exists, :ok} ==
                 Noncer.do_check(arrived_at, curr_ts, @nonce_freezing_secs, @precision)
      end
    end

    test "ok - not freezing" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - @nonce_freezing_secs
      ) do
        assert {arrived_at, :not_freezing, :ok} ==
                 Noncer.do_check(arrived_at, curr_ts, @nonce_freezing_secs, @precision)
      end
    end

    test "invalid nonce - freezing" do
      with(
        curr_ts <- 1_622_474_344,
        arrived_at <- curr_ts - @nonce_freezing_secs + 10
      ) do
        assert {arrived_at, :freezing, :invalid_nonce} ==
                 Noncer.do_check(arrived_at, curr_ts, @nonce_freezing_secs, @precision)
      end
    end
  end
end
