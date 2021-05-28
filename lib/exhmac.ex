defmodule ExHmac do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use ExHmac.Use, unquote(opts)
    end
  end
end
