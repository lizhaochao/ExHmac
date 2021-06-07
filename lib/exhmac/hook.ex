defmodule ExHmac.Hook do
  @moduledoc false

  def pre_hook(args, config) do
    with(
      %ExHmac.Config{impl_m: impl_m} <- config,
      {f, a} <- __ENV__.function,
      true <- function_exported?(impl_m, f, a - 1),
      new_args <- apply(impl_m, f, [args]),
      :ok <- check_keyword(new_args)
    ) do
      new_args
    else
      false -> args
      err -> err
    end
  end

  def post_hook(resp, config) do
    with(
      %ExHmac.Config{impl_m: impl_m} <- config,
      {f, a} <- __ENV__.function,
      true <- function_exported?(impl_m, f, a - 1),
      new_resp <- apply(impl_m, f, [resp])
    ) do
      new_resp
    else
      false -> resp
    end
  end

  ###
  defp check_keyword(term) do
    term
    |> Keyword.keyword?()
    |> case do
      true -> :ok
      _ -> :pre_hook_result_must_be_keyword
    end
  end
end
