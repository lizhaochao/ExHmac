defmodule ExHmac.Use.Decorator do
  @moduledoc false

  alias ExHmac.{Config, Checker}
  alias ExHmac.Use.Helper
  alias ExHmac.Use.Decorator, as: Self

  defmacro __using__(opts) do
    quote do
      def check_hmac(body, %Decorator.Decorate.Context{} = ctx) do
        config = unquote(opts) |> Config.get_config() |> Map.put(:impl_m, __MODULE__)
        Self.pre_check(config)

        with config_expr <- Macro.escape(config),
             %{args: args_expr} <- ctx do
          args_expr
          |> Self.make_arg_names()
          |> Self.check_hmac(args_expr, body, config_expr)
        end
      end
    end
  end

  def check_hmac(arg_names, args_expr, body, config_expr) do
    quote do
      with exec_body <- fn -> unquote(body) end,
           arg_values <- unquote(args_expr),
           args <- Self.make_args(unquote(arg_names), arg_values) do
        Self.do_check_hmac(args, exec_body, unquote(config_expr))
      end
    end
  end

  def pre_check(config) do
    %{impl_m: impl_m, get_secret_key_function_name: get_secret_key_function_name} = config
    Checker.require_function!(impl_m, get_secret_key_function_name, 1)
  end

  ###
  def do_check_hmac(args, exec_body, config)
      when is_list(args) and is_function(exec_body) do
    with access_key when is_bitstring(access_key) <- get_access_key(args, config),
         secret_key when is_bitstring(secret_key) <- get_secret_key(access_key, config),
         resp <- do_check_hmac(args, access_key, secret_key, exec_body, config),
         resp <- fmt_resp(resp, config) do
      Helper.make_resp(resp, config, access_key, secret_key)
    else
      err_without_hmac -> err_without_hmac |> fmt_resp(config) |> Helper.make_resp(config)
    end
  end

  def do_check_hmac(args, access_key, secret_key, exec_body, config) do
    with :ok <- Helper.check_timestamp(args, config),
         :ok <- Helper.check_nonce(args, config),
         :ok <- Helper.check_signature(args, access_key, secret_key, config) do
      exec_body.()
    else
      err -> err
    end
  end

  def make_arg_names(args_expr) do
    Enum.map(args_expr, fn {name, _, _} ->
      name
      |> to_string()
      |> case do
        "_" <> _rest = str_name -> String.slice(str_name, 1, String.length(str_name) - 1)
        str_name -> str_name
      end
      |> String.to_atom()
    end)
  end

  def make_args(arg_names, arg_values), do: do_make_args(arg_names, arg_values, [])

  def do_make_args([], [], args), do: args

  def do_make_args([name | rest_names], [value | rest_values], args) do
    do_make_args(rest_names, rest_values, [{name, value} | args])
  end

  ###
  def get_access_key(args, config) do
    %{access_key_name: access_key_name} = config

    args
    |> Keyword.fetch(access_key_name)
    |> case do
      :error -> :not_found_access_key
      {:ok, access_key} when is_bitstring(access_key) and access_key != "" -> access_key
      _access_key -> :access_key_error
    end
  end

  def get_secret_key(access_key, config) do
    %{impl_m: impl_m, get_secret_key_function_name: get_secret_key_function_name} = config

    impl_m
    |> apply(get_secret_key_function_name, [access_key])
    |> case do
      secret_key when is_bitstring(secret_key) -> secret_key
      secret_key when is_nil(secret_key) or secret_key == "" -> :access_key_error
      err when is_atom(err) -> err
      _ -> :get_secret_key_error
    end
  end

  ###
  def fmt_resp(resp, config) do
    with(
      %{impl_m: impl_m} <- config,
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
