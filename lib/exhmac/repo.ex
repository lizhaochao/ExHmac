defmodule ExHmac.Repo do
  @moduledoc false
  alias ExHmac.KVRepo

  def get(key, config) do
    config
    |> f_exported?(__ENV__.function)
    |> case do
      {impl_m, f_name} -> apply(impl_m, f_name, [key])
      :default -> KVRepo.fetch(key)
    end
  end

  def update(key, value, config) do
    config
    |> f_exported?(__ENV__.function)
    |> case do
      {impl_m, f_name} -> apply(impl_m, f_name, [key, value])
      :default -> KVRepo.put(key, value)
    end
  end

  def delete(keys, config) do
    config
    |> f_exported?(__ENV__.function)
    |> case do
      {impl_m, f_name} -> apply(impl_m, f_name, [keys])
      :default -> KVRepo.drop(keys)
    end
  end

  ###
  defp f_exported?(config, function) do
    with %{impl_m: impl_m} <- config,
         {f_name, f_arity} <- function,
         true <- function_exported?(impl_m, f_name, f_arity - 1) do
      {impl_m, f_name}
    else
      false -> :default
    end
  end
end
