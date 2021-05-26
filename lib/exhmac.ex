defmodule ExHmac do
  @moduledoc false

  # use Decorator.Define, check_hmac: 0

  def check_hmac(body, ctx) do
    quote do
      # 1. to atom

      use ExHmac.Use
    end
  end
end
