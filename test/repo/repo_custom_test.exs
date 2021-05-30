defmodule Repo.Hmac do
  def get(key), do: {:ok, key}
  def update(key, value), do: {:ok, key, value}
  def delete(keys), do: {:ok, keys}
end

defmodule RepoCustomTest do
  use ExUnit.Case

  alias ExHmac.{Config, Repo}

  @config [] |> Config.get_config() |> Map.put(:impl_m, Elixir.Repo.Hmac)

  test "get" do
    assert {:ok, :ljy} == Repo.get(:ljy, @config)
  end

  test "update" do
    assert {:ok, :name, :ljy} == Repo.update(:name, :ljy, @config)
  end

  test "delete" do
    assert {:ok, [:name]} == Repo.delete([:name], @config)
  end
end
