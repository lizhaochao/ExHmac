defmodule KVRepoTest do
  ### ### ### ### ### !!! NOTICE !!! ### ### ### ### ###
  ###       If Failed, Run The Following Command:    ###
  ###                mix test --seed 0               ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  use ExUnit.Case
  alias ExHmac.KVRepo

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

  test "fetch above tests values" do
    assert {:ok, "ljy"} == KVRepo.fetch(:name1)
    assert {:ok, "lijiayou"} == KVRepo.fetch(:name2)
  end

  test "drop" do
    assert :ok == KVRepo.drop([:name1, :name2])
    assert :error == KVRepo.fetch(:name1)
    assert :error == KVRepo.fetch(:name1)
  end

  describe "get_and_update" do
    test "current is nil" do
      with value <- :ljy,
           expected <- [value],
           fun <- update_fun(value) do
        {value, _} = KVRepo.get_and_update(:name, fun)
        assert nil == value
        assert {:ok, expected} == KVRepo.fetch(:name)
      end
    end

    test "current is not nil" do
      with init_value <- :ljy,
           :ok <- KVRepo.put(:name, [init_value]),
           value <- :lzc,
           expected <- [value, init_value],
           fun <- update_fun(value) do
        {value, _} = KVRepo.get_and_update(:name, fun)
        assert [init_value] == value
        assert {:ok, expected} == KVRepo.fetch(:name)
      end
    end
  end

  ### Helper
  def update_fun(value) do
    fn current ->
      new = (current && [value | current]) || [value]
      {current, new}
    end
  end
end
