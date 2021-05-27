defmodule ExHmac.Signer do
  @moduledoc false

  alias ExHmac.Error

  ###
  def make_sign_string(args, access_key, secret_key, opts)
      when is_list(args) and is_bitstring(access_key) and is_bitstring(secret_key) and
             is_map(opts) do
    with maker = do_make_sign_string(args, access_key, secret_key),
         %{
           access_key_name: access_key_name,
           secret_key_name: secret_key_name,
           signature_name: signature_name
         } <- opts do
      maker.(signature_name, access_key_name, secret_key_name)
    else
      _ -> raise(Error, "opts error")
    end
  end

  def make_sign_string(_, _, _, _), do: raise(Error, "make sign string error")

  def do_make_sign_string(args, access_key, secret_key) do
    fn signature_name, access_key_name, secret_key_name ->
      args
      |> Keyword.drop([signature_name])
      |> Keyword.put(access_key_name, access_key)
      |> Keyword.put(secret_key_name, secret_key)
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=#{to_json_string(v)}" end)
      |> Enum.join("&")
    end
  end

  def to_json_string(term) when is_bitstring(term), do: term
  def to_json_string(term) when is_atom(term), do: Atom.to_string(term)

  def to_json_string(term) do
    term
    |> Poison.encode()
    |> case do
      {:ok, result} -> result
      err -> raise(Error, "to json string error: #{inspect(err)}")
    end
  end

  ###
  def do_sign(sign_string, alg) when is_bitstring(sign_string) and is_atom(alg) do
    case alg do
      :sha512 -> sha512(sign_string)
      :md5 -> md5(sign_string)
      _ -> sha256(sign_string)
    end
  end

  def sha512(term) when is_bitstring(term) do
    :sha512 |> :crypto.hash(term) |> Base.encode16(case: :lower)
  end

  def sha256(term) when is_bitstring(term) do
    :sha256 |> :crypto.hash(term) |> Base.encode16(case: :lower)
  end

  def md5(term) when is_bitstring(term) do
    :md5 |> :crypto.hash(term) |> Base.encode16(case: :lower)
  end
end
