defmodule ExHmac.Use.Helper do
  @moduledoc false

  alias ExHmac.{Checker, Signer, Noncer, Util}

  def check_timestamp(args, config) do
    with %{timestamp_name: timestamp_name} <- config,
         {:ok, timestamp} <- Keyword.fetch(args, timestamp_name) do
      Checker.check_timestamp(timestamp, config)
    else
      :error -> :not_found_timestamp
      err -> err
    end
  end

  def check_nonce(args, config) do
    with %{nonce_name: nonce_name} <- config,
         {:ok, nonce} <- Keyword.fetch(args, nonce_name) do
      Checker.check_nonce(nonce, config)
    else
      :error -> :not_found_nonce
      err -> err
    end
  end

  def check_signature(args, access_key, secret_key, config) do
    with %{signature_name: signature_name} <- config,
         {signature, args} when not is_nil(signature) <- Keyword.pop(args, signature_name),
         my_signature <- sign(args, access_key, secret_key, config),
         true <- signature == my_signature do
      :ok
    else
      _ -> :signature_error
    end
  end

  ###
  def sign(args, access_key, secret_key, config) do
    with %{hash_alg: hash_alg} <- config,
         sign_string <- Signer.make_sign_string(args, access_key, secret_key, config) do
      do_sign(hash_alg, sign_string, access_key)
    end
  end

  def do_sign(hash_alg, sign_string, access_key) do
    with true <- Util.contain_hmac?(hash_alg),
         hash_alg <- Util.prune_hash_alg(hash_alg) do
      Signer.do_sign(sign_string, hash_alg, access_key)
    else
      false -> Signer.do_sign(sign_string, hash_alg)
    end
  end

  ###
  def gen_timestamp(prec, config) do
    with precision <- prec || Map.get(config, :precision) do
      Util.get_curr_ts(precision)
    end
  end

  ###
  def gen_nonce(len, config) do
    with nonce_len <- len || Map.get(config, :nonce_len) do
      Noncer.gen_nonce(nonce_len)
    end
  end

  ###
  def make_resp({:default, resp}, config) do
    resp_data_name = get_resp_data_name(resp, config)
    Keyword.put([], resp_data_name, resp)
  end

  def make_resp({:fmt, resp}, _config) do
    resp
    |> Checker.keyword_or_map!("resp")
    |> Util.to_keyword()
  end

  def make_resp({:default, _} = default_resp, config, access_key, secret_key) do
    default_resp
    |> make_resp(config)
    |> append_hmac(config, access_key, secret_key)
  end

  def make_resp({:fmt, resp}, config, access_key, secret_key) do
    resp
    |> Checker.keyword_or_map!("resp")
    |> Util.to_keyword()
    |> append_hmac(config, access_key, secret_key)
  end

  #
  def append_hmac(resp, config, access_key, secret_key) do
    with args <- make_resp_args(resp, config),
         signature <- sign(args, access_key, secret_key, config),
         args <- put_signature(args, signature, config) do
      args
    end
  end

  def make_resp_args(resp, config) do
    with %{
           timestamp_name: timestamp_name,
           nonce_name: nonce_name
         } <- config do
      []
      |> Keyword.put(timestamp_name, gen_timestamp(nil, config))
      |> Keyword.put(nonce_name, gen_nonce(nil, config))
      |> Keyword.merge(resp)
    end
  end

  def put_signature(args, signature, config) do
    with %{signature_name: signature_name} <- config do
      Keyword.put(args, signature_name, signature)
    end
  end

  def get_resp_data_name(resp, config) do
    %{
      resp_succ_data_name: resp_succ_data_name,
      resp_fail_data_name: resp_fail_data_name
    } = config

    case resp do
      resp when is_atom(resp) -> resp_fail_data_name
      _resp -> resp_succ_data_name
    end
  end
end
