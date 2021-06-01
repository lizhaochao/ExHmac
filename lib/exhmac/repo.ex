defmodule ExHmac.Repo do
  @moduledoc false

  alias ExHmac.KVRepo

  def get_repo, do: KVRepo.get_repo()

  def get(key), do: KVRepo.fetch(key)
  def get_and_update(key, fun) when is_function(fun), do: KVRepo.get_and_update(key, fun)
  def update(key, value), do: KVRepo.put(key, value)
  def delete(keys) when is_list(keys), do: KVRepo.drop(keys)
end
