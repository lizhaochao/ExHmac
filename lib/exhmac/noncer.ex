defmodule ExHmac.Noncer do
  @moduledoc false

  def get_created_at(_nonce) do
    nil
  end

  def gen_nonce(len), do: gen_random(trunc(len / 2))

  defp gen_random(bits), do: bits |> :crypto.strong_rand_bytes() |> Base.encode16()
end
