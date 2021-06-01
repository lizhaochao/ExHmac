defmodule RepoTest do
  ### ### ### ### ### !!! NOTICE !!! ### ### ### ### ###
  ###       If Failed, Run The Following Command:    ###
  ###                mix test --seed 0               ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  use ExUnit.Case
  alias ExHmac.{Config, Repo}

  setup_all do
    config = Config.get_config([])
    %{config: config}
  end

  test "get", %{config: config} do
    assert :error == Repo.get(:ljy, config)
  end

  test "update", %{config: config} do
    assert :ok == Repo.update(:name, :ljy, config)
  end

  test "delete", %{config: config} do
    assert :ok == Repo.delete([:name], config)
  end

  test "get -> update -> get -> delete -> get", %{config: config} do
    key = :any_key
    assert :error == Repo.get(key, config)
    assert :ok == Repo.update(key, :ljy, config)
    assert {:ok, :ljy} == Repo.get(key, config)
    assert :ok == Repo.delete([key], config)
    assert :error == Repo.get(key, config)
  end
end
