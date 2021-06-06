defmodule ExHmac.Use.Decorator do
  @moduledoc false

  alias ExHmac.Config
  alias ExHmac.Use.Helper
  alias ExHmac.Use.Decorator, as: Self

  defmacro __using__(opts) do
    quote do
      def check_hmac(block, %Decorator.Decorate.Context{} = ctx) do
        config = unquote(opts) |> Config.get_config() |> Helper.put_impl_m(__MODULE__)
        Helper.pre_check(config)

        with config_expr <- Macro.escape(config),
             %{args: args_expr} <- ctx do
          args_expr
          |> Helper.make_arg_names()
          |> Self.check_hmac(args_expr, block, config_expr)
        end
      end
    end
  end

  def check_hmac(arg_names, args_expr, block, config_expr) do
    quote do
      with exec_block <- fn -> unquote(block) end,
           arg_values <- unquote(args_expr),
           args <- Helper.make_args(unquote(arg_names), arg_values),
           config <- unquote(config_expr) |> Helper.save_config() do
        Helper.do_check_hmac(args, exec_block, config)
      end
    end
  end
end
