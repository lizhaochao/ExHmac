defmodule ExHmac.Repo do
  @moduledoc false

  alias ExHmac.KVRepo

  ###
  def get(fun) when is_function(fun), do: KVRepo.get(fun)
  def update(fun) when is_function(fun), do: KVRepo.update(fun)

  ###
  def reinit, do: KVRepo.init()
  def get_all, do: KVRepo.get_repo()
end
