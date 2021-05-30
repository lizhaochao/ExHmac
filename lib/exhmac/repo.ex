defmodule ExHmac.Repo do
  @moduledoc false
  alias ExHmac.KVRepo

  def get(key, _config) do
    KVRepo.fetch(key)
  end

  def update(key, value, _config) do
    KVRepo.put(key, value)
  end

  def delete(keys, _config) do
    KVRepo.drop(keys)
  end
end
