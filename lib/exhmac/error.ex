defmodule ExHmac.Error do
  @moduledoc false

  def syntax_error(term) do
    raise __MODULE__, "invalid syntax: #{inspect(term)}"
  end

  def warn(text, true = _warn), do: IO.warn(text, [])
  def warn(_text, _warn), do: :ignore
end
