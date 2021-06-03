defmodule ExHmac.Use.Defhmac do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      defmacro defhmac(call, do: block) do
        {_f, _, [_ | _] = _a} = call
        fun_expr = {:def, [], [call, [do: block]]}

        quote do
          unquote(fun_expr)
        end
      end
    end
  end
end
