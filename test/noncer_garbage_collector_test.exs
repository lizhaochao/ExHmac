defmodule GarbageCollectorTest do
  use ExUnit.Case

  alias ExHmac.Noncer.GarbageCollector, as: GC
  alias ExHmac.{Noncer, Repo}

  setup_all do
    Repo.reinit()
    :ok
  end

  test "ok" do
    %{
      0 => {min0, nonce0},
      1 => {min1, nonce1},
      2 => {min2, nonce2},
      3 => {min3, nonce3}
    } = test_data()

    fn repo ->
      # GC don't care nonce's arrived_at.
      repo =
        put_in(repo, [:nonces], %{
          nonce0 => 1_622_573_000,
          nonce1 => 1_622_573_111,
          nonce2 => 1_622_573_222,
          nonce3 => 1_622_573_333
        })

      repo =
        put_in(repo, [:meta, :shards], %{
          min0 => MapSet.new([nonce0]),
          min1 => MapSet.new([nonce1]),
          min2 => MapSet.new([nonce2]),
          min3 => MapSet.new([nonce3])
        })

      mins = [min0, min1, min2, min3]
      repo = put_in(repo, [:meta, :mins], MapSet.new(mins))
      repo = put_in(repo, [:meta, :counts], %{min0 => 1, min1 => 1, min2 => 1, min3 => 1})
      {nil, repo}
    end
    |> Repo.get()

    with(
      ttl_min <- 15,
      curr_min <- min2 + ttl_min + 1
    ) do
      Enum.each(1..3, fn _ ->
        assert :ok == GC.do_collect(curr_min, ttl_min)
        Process.sleep(10)
        assert_collect_after()
      end)
    end
  end

  ### Helper
  def test_data do
    # {min, nonce}
    %{
      0 => {27_042_870, "AAA000"},
      1 => {27_042_871, "BBB111"},
      2 => {27_042_872, "CCC222"},
      3 => {27_042_873, "DDD333"}
    }
  end

  def assert_collect_after do
    %{
      0 => {min0, nonce0},
      3 => {min3, nonce3}
    } = test_data()

    %{meta: %{counts: counts, mins: mins, shards: shards}, nonces: nonces} = Noncer.all()

    assert %{min0 => 1, min3 => 1} == counts
    assert MapSet.new([min0, min3]) == mins
    assert %{min0 => MapSet.new([nonce0]), min3 => MapSet.new([nonce3])} == shards
    assert [nonce0, nonce3] == Map.keys(nonces)
  end
end
