defmodule ExHmac.Repo do
  @moduledoc false
  alias ExHmac.KVRepo

  ###
  def create(key, value, _config) do
    fun = fn current ->
      new = if is_nil(current), do: value, else: current
      {current, new}
    end

    key
    |> KVRepo.get_and_update(fun)
    |> case do
      {new, _} when new == value -> :ok
      _ -> :error
    end
  end

  def get(key, _config) do
    KVRepo.fetch(key)
  end

  def update(key, value, _config) do
    KVRepo.put(key, value)
  end

  def delete(keys, _config) do
    KVRepo.drop(keys)
  end

  ###
  def get_and_update(key, fun, _config) do
    KVRepo.get_and_update(key, fun)
  end
end
