defmodule ExHmac.Error do
  @moduledoc false

  defexception message: nil

  def warn(text, true = _warn), do: IO.warn(text, [])
  def warn(_text, _warn), do: :ignore
end
