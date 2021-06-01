defmodule ExHmac.Repo do
  @moduledoc false

  alias ExHmac.KVRepo

  ###
  def get_and_update_nonce(fun) when is_function(fun) do
    KVRepo.get_and_update_nonce(fun)
  end

  def update_meta(fun) when is_function(fun), do: KVRepo.update_meta(fun)

  ###
  def get_all, do: KVRepo.get_repo()
  def get(key), do: KVRepo.fetch(key)
  def get_in(path) when is_list(path), do: KVRepo.get_in(path)
  def get_and_update(key, fun) when is_function(fun), do: KVRepo.get_and_update(key, fun)
  def update(key, value), do: KVRepo.put(key, value)
  def update_in(path, value), do: KVRepo.put_in(path, value)
  def delete(keys) when is_list(keys), do: KVRepo.drop(keys)
end
