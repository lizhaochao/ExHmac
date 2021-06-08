defmodule ExHmac.Use.Helper do
  @moduledoc false

  alias ExHmac.{Checker, Repo}

  def pre_check(config) do
    %ExHmac.Config{impl_m: impl_m, get_secret_key_fun_name: get_secret_key_fun_name} = config
    Checker.require_function!(impl_m, get_secret_key_fun_name, 1)
  end

  def make_arg_names(args_expr) do
    Enum.map(args_expr, fn {name, _, _} ->
      name
      |> to_string()
      |> case do
        "_" <> str_name -> str_name
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
  def pre_config(config, impl_m), do: config |> put_impl_m(impl_m) |> save_config()

  def put_impl_m(config, impl_m) do
    Map.put(config, :impl_m, impl_m)
  end

  def save_config(config) do
    with(
      new_config <- Map.take(config, [:precision, :nonce_freezing_secs]),
      fun <- fn repo ->
        new_repo = put_in(repo, [:config], new_config)
        {new_config, new_repo}
      end,
      _ <- Repo.sync_update(fun)
    ) do
      config
    end
  end
end
