defmodule ExHmac.Callback do
  @moduledoc false

  ### customize callback name
  def get_access_key(args, config) do
    %ExHmac.Config{
      impl_m: impl_m,
      get_access_key_fun_name: get_access_key_fun_name,
      access_key_name: access_key_name
    } = config

    if function_exported?(impl_m, get_access_key_fun_name, 1) do
      apply(impl_m, get_access_key_fun_name, [args])
    else
      args
      |> Keyword.fetch(access_key_name)
      |> case do
        {:ok, access_key} -> access_key
        err -> err
      end
    end
  end

  def make_sign_string(args, access_key, secret_key, config) do
    with(
      %ExHmac.Config{
        impl_m: impl_m,
        make_sign_string_fun_name: make_sign_string_fun_name
      } <- config,
      true <- function_exported?(impl_m, make_sign_string_fun_name, 3)
    ) do
      apply(impl_m, make_sign_string_fun_name, [args, access_key, secret_key])
    else
      false -> :default
    end
  end

  def encode_hash_result(config) do
    %ExHmac.Config{
      impl_m: impl_m,
      encode_hash_result_fun_name: encode_hash_result_fun_name
    } = config

    with(
      exported? <- function_exported?(impl_m, encode_hash_result_fun_name, 1),
      encode_fun <- fn hash_result ->
        apply(impl_m, encode_hash_result_fun_name, [hash_result])
      end
    ) do
      (exported? && encode_fun) || nil
    end
  end

  ### same function name
  def check_nonce(nonce, args, %ExHmac.Config{} = config) when is_bitstring(nonce) do
    with(
      %{impl_m: impl_m} <- config,
      {f, _a} <- __ENV__.function,
      true <- function_exported?(impl_m, f, 4)
    ) do
      apply(impl_m, f, args)
    else
      false = result -> result
    end
  end

  def fmt_resp(resp, config) do
    with(
      %ExHmac.Config{impl_m: impl_m} <- config,
      {f, a} <- __ENV__.function,
      true <- function_exported?(impl_m, f, a - 1),
      resp <- apply(impl_m, f, [resp])
    ) do
      {:fmt, resp}
    else
      false -> {:default, resp}
    end
  end
end
