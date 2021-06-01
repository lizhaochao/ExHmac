defmodule ExHmac.Repo do
  @moduledoc false

  alias ExHmac.KVRepo

  def get_repo, do: KVRepo.get_repo()

  def get(key, config) do
    config
    |> f_exported?(__ENV__.function)
    |> case do
      {impl_m, f} -> apply(impl_m, f, [key])
      :default -> KVRepo.fetch(key)
    end
  end

  def get_and_update(key, fun) when is_function(fun), do: KVRepo.get_and_update(key, fun)

  def update(key, value, config) do
    config
    |> f_exported?(__ENV__.function)
    |> case do
      {impl_m, f} -> apply(impl_m, f, [key, value])
      :default -> KVRepo.put(key, value)
    end
  end

  def delete(keys, config) when is_list(keys) do
    config
    |> f_exported?(__ENV__.function)
    |> case do
      {impl_m, f} -> apply(impl_m, f, [keys])
      :default -> KVRepo.drop(keys)
    end
  end

  ###
  defp f_exported?(config, function) do
    with %{impl_m: impl_m} <- config,
         {f, a} <- function,
         true <- function_exported?(impl_m, f, a - 1) do
      {impl_m, f}
    else
      false -> :default
    end
  end
end
