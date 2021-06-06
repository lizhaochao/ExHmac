defmodule ExHmac.Use.Defhmac do
  @moduledoc false

  alias ExHmac.Parser
  alias ExHmac.Use.Helper
  alias ExHmac.Use.Defhmac, as: Self

  defmacro __using__(opts) do
    quote do
      defmacro defhmac(call, do: block) do
        with(
          config <- Helper.fill_config(unquote(opts), __MODULE__),
          _ <- Helper.pre_check(config),
          {f, a, guard} <- Parser.parser(call)
        ) do
          Self.make_function(f, a, guard, block, config)
        end
      end
    end
  end

  def make_function(f, a, guard, block, config) do
    quote do
      def unquote(f)(unquote_splicing(a)) when unquote(guard) do
        with(
          args <- unquote(make_args(a)),
          exec_block <- fn -> unquote(block) end,
          config <- unquote(Macro.escape(config))
        ) do
          Helper.do_check_hmac(args, exec_block, config)
        end
      end
    end
  end

  def make_args(a_expr) do
    quote do
      keys = unquote(Helper.make_arg_names(a_expr))
      values = [unquote_splicing(a_expr)]
      Helper.make_args(keys, values)
    end
  end
end
