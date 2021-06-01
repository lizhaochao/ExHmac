defmodule RepoTest do
  ### ### ### ### ### !!! NOTICE !!! ### ### ### ### ###
  ###       If Failed, Run The Following Command:    ###
  ###                mix test --seed 0               ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  use ExUnit.Case
  alias ExHmac.Repo

  test "get" do
    assert :error == Repo.get(:ljy)
  end

  test "update" do
    assert :ok == Repo.update(:name, :ljy)
  end

  test "delete" do
    assert :ok == Repo.delete([:name])
  end

  test "get -> update -> get -> delete -> get" do
    key = :any_key
    assert :error == Repo.get(key)
    assert :ok == Repo.update(key, :ljy)
    assert {:ok, :ljy} == Repo.get(key)
    assert :ok == Repo.delete([key])
    assert :error == Repo.get(key)
  end
end
