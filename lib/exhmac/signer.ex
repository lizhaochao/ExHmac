defmodule ExHmac.Signer do
  @moduledoc false

  alias ExHmac.Const

  @default_access_key_name Const.default_access_key_name()
  @default_secret_key_name Const.default_secret_key_name()
  @default_signature_name Const.default_signature_name()

  def make_sign_string(args, access_key, secret_key)
      when is_list(args) and is_bitstring(access_key) and is_bitstring(secret_key) do
    args
    |> Keyword.drop([@default_signature_name])
    |> Keyword.put(@default_access_key_name, access_key)
    |> Keyword.put(@default_secret_key_name, secret_key)
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join("&")
  end

  def sign(sign_string, alg) when is_bitstring(sign_string) and is_atom(alg) do
    case alg do
      :md5 -> md5(sign_string)
      _ -> sha256(sign_string)
    end
  end

  def sha256(term) when is_bitstring(term) do
  end

  def md5(term) when is_bitstring(term) do
  end
end
