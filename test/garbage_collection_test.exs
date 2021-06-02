defmodule GarbageCollectionTest do
  use ExUnit.Case

  alias ExHmac.Noncer.GarbageCollection, as: GC
  alias ExHmac.{Noncer, Repo}

  setup_all do
    Repo.reinit()
    :ok
  end

  test "ok" do
    {min0, nonce0} = {27_042_870, "000000"}
    {min1, nonce1} = {27_042_871, "AAA111"}
    {min2, nonce2} = {27_042_872, "BBB222"}
    {min3, nonce3} = {27_042_873, "CCC333"}

    fn repo ->
      mins = [min0, min1, min2, min3]

      repo =
        put_in(repo, [:nonces], %{
          nonce0 => 1_622_573_000,
          nonce1 => 1_622_573_111,
          nonce2 => 1_622_573_222,
          nonce3 => 1_622_573_333
        })

      repo = put_in(repo, [:meta, :mins], MapSet.new(mins))
      repo = put_in(repo, [:meta, :counts], %{min0 => 1, min1 => 1, min2 => 1, min3 => 1})

      repo =
        put_in(repo, [:meta, :shards], %{
          min0 => MapSet.new([nonce0]),
          min1 => MapSet.new([nonce1]),
          min2 => MapSet.new([nonce2]),
          min3 => MapSet.new([nonce3])
        })

      {nil, repo}
    end
    |> Repo.get()

    with(
      ttl_min <- 15,
      curr_min <- min2 + ttl_min + 1
    ) do
      assert :ok == GC.do_collect(curr_min, ttl_min)

      %{meta: %{counts: counts, mins: mins, shards: shards}, nonces: nonces} = Noncer.all()

      assert %{min0 => 1, min3 => 1} == counts
      assert MapSet.new([min0, min3]) == mins
      assert %{min0 => MapSet.new([nonce0]), min3 => MapSet.new([nonce3])} == shards
      assert [nonce0, nonce3] == Map.keys(nonces)
    end
  end
end
