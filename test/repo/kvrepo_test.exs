defmodule KVRepoTest do
  use ExUnit.Case

  alias ExHmac.KVRepo

  setup_all do
    start_supervised!(KVRepo)
    :ok
  end

  test "fetch not exists key" do
    assert :error == KVRepo.fetch(:any_key)
  end

  test "only put" do
    assert :ok == KVRepo.put(:name1, "ljy")
  end

  test "put -> fetch" do
    assert :ok == KVRepo.put(:name2, "lijiayou")
    assert {:ok, "lijiayou"} == KVRepo.fetch(:name2)
  end

  # if failed, run command: mix test --seed 0
  test "fetch above tests values" do
    assert {:ok, "ljy"} == KVRepo.fetch(:name1)
    assert {:ok, "lijiayou"} == KVRepo.fetch(:name2)
  end
end
