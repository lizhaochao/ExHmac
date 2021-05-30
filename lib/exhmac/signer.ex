defmodule ExHmac.Signer do
  @moduledoc false

  alias ExHmac.{Config, Error, Util}

  @support_hash_algs Config.support_hash_algs()

  ###
  def make_sign_string(args, access_key, secret_key, config)
      when is_list(args) and is_bitstring(access_key) and is_bitstring(secret_key) and
             is_map(config) do
    with maker <- do_make_sign_string(args, access_key, secret_key),
         %{
           access_key_name: access_key_name,
           secret_key_name: secret_key_name,
           signature_name: signature_name
         } <- config,
         sign_string <- maker.(signature_name, access_key_name, secret_key_name),
         _ <- Util.log_debug(sign_string: sign_string) do
      sign_string
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
  def do_sign(sign_string, alg, access_key \\ nil)

  def do_sign(sign_string, alg, access_key)
      when is_bitstring(sign_string) and alg in @support_hash_algs and
             (is_nil(access_key) or is_bitstring(access_key)) do
    with hash_result <- hash(sign_string, alg, access_key),
         _ <- do_sign_log(hash_result, alg, access_key) do
      hash_result
    end
  end

  def do_sign(_sign_string, alg, _access_key) when alg not in @support_hash_algs do
    raise Error, "not support hash alg: #{inspect(alg)}"
  end

  def do_sign(_, _, _), do: raise(Error, "do sign error")

  def do_sign_log(hash_result, alg, access_key) do
    with log <- [alg: alg, hash_result: hash_result],
         extra <- (access_key && [access_key: access_key]) || [] do
      Util.log_debug(log ++ extra)
    end
  end

  def hash(term, alg, access_key \\ nil)
  def hash(term, alg, nil = _access_key), do: hex_string(:crypto.hash(alg, term))
  def hash(term, alg, access_key), do: hex_string(:crypto.mac(:hmac, alg, access_key, term))

  defp hex_string(binary), do: Base.encode16(binary, case: :lower)
end
