defmodule ExHmac do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use Decorator.Define, check_hmac: 0
      use ExHmac.Use.Decorator, unquote(opts)
      use ExHmac.Use, unquote(opts)
    end
  end
end

defmodule ExHmac.Defhmac do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use ExHmac.Use.Defhmac, unquote(opts)
    end
  end
end
