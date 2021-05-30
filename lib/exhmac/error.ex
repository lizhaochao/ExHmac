defmodule ExHmac.Error do
  @moduledoc false

  alias ExHmac.Util

  defexception message: nil

  def warn(text, true = _warn) do
    IO.warn(text, [])
    Util.log_warn(text)
  end

  def warn(_text, _warn), do: :ignore
end
