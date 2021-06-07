defmodule ExHmac.Core do
  @moduledoc false

  alias ExHmac.{Callback, Checker, Hook, Noncer, Signer, Util}

  def do_check_hmac(args, exec_block, config)
      when is_list(args) and is_function(exec_block) do
    with(
      [_ | _] = args <- Hook.pre_hook(args, config),
      access_key when is_bitstring(access_key) <- get_access_key(args, config),
      secret_key when is_bitstring(secret_key) <- get_secret_key(access_key, config),
      resp <- do_check_hmac(args, access_key, secret_key, config, exec_block),
      resp <- fmt_resp(resp, config)
    ) do
      make_resp_with_hmac(resp, config, access_key, secret_key)
    else
      err_without_hmac -> err_without_hmac |> fmt_resp(config) |> make_resp_with_hmac(config)
    end
    |> Hook.post_hook(config)
  end

  def do_check_hmac(args, access_key, secret_key, config, exec_block \\ fn -> :ok end) do
    with :ok <- check_timestamp(args, config),
         :ok <- check_nonce(args, config),
         :ok <- check_signature(args, access_key, secret_key, config) do
      exec_block.()
    else
      err -> err
    end
  end

  ###
  def get_access_key(args, config) do
    args
    |> Callback.get_access_key(config)
    |> case do
      access_key when is_bitstring(access_key) and access_key != "" -> access_key
      :error -> :not_found_access_key
      _other -> :get_access_key_error
    end
  end

  def get_secret_key(access_key, config) do
    %ExHmac.Config{impl_m: impl_m, get_secret_key_fun_name: get_secret_key_fun_name} = config

    impl_m
    |> apply(get_secret_key_fun_name, [access_key])
    |> case do
      secret_key when is_bitstring(secret_key) -> secret_key
      secret_key when is_nil(secret_key) or secret_key == "" -> :secret_key_error
      err when is_atom(err) -> err
      _ -> :get_secret_key_error
    end
  end

  ###
  def fmt_resp(resp, config), do: Callback.fmt_resp(resp, config)

  def make_resp_with_hmac({:default, resp}, config) do
    resp_data_name = get_resp_data_name(resp, config)
    Keyword.put([], resp_data_name, resp)
  end

  def make_resp_with_hmac({:fmt, resp}, _config) do
    resp
    |> Checker.keyword_or_map!("resp")
    |> Util.to_keyword()
  end

  def make_resp_with_hmac({:default, _} = default_resp, config, access_key, secret_key) do
    default_resp
    |> make_resp_with_hmac(config)
    |> append_hmac(config, access_key, secret_key)
  end

  def make_resp_with_hmac({:fmt, resp}, config, access_key, secret_key) do
    resp
    |> Checker.keyword_or_map!("resp")
    |> Util.to_keyword()
    |> append_hmac(config, access_key, secret_key)
  end

  def append_hmac(resp, config, access_key, secret_key) do
    with args <- make_resp_with_hmac_args(resp, config),
         signature <- sign(args, access_key, secret_key, config),
         args <- put_signature(args, signature, config) do
      args
    end
  end

  def make_resp_with_hmac_args(resp, config) do
    %ExHmac.Config{timestamp_name: timestamp_name, nonce_name: nonce_name} = config

    []
    |> Keyword.put(timestamp_name, gen_timestamp(config))
    |> Keyword.put(nonce_name, gen_nonce(config))
    |> Keyword.merge(resp)
  end

  def put_signature(args, signature, config) do
    with %ExHmac.Config{signature_name: signature_name} <- config do
      Keyword.put(args, signature_name, signature)
    end
  end

  def get_resp_data_name(resp, config) do
    %ExHmac.Config{
      resp_succ_data_name: resp_succ_data_name,
      resp_fail_data_name: resp_fail_data_name
    } = config

    case resp do
      resp when is_atom(resp) -> resp_fail_data_name
      _resp -> resp_succ_data_name
    end
  end

  ###
  def check_timestamp(args, config) do
    with %ExHmac.Config{timestamp_name: timestamp_name} <- config,
         {:ok, timestamp} <- Keyword.fetch(args, timestamp_name) do
      Checker.check_timestamp(timestamp, config)
    else
      :error -> :not_found_timestamp
      err -> err
    end
  end

  def check_nonce(args, config) do
    with %ExHmac.Config{nonce_name: nonce_name} <- config,
         {:ok, nonce} <- Keyword.fetch(args, nonce_name) do
      Checker.check_nonce(nonce, config)
    else
      :error -> :not_found_nonce
      err -> err
    end
  end

  def check_signature(args, access_key, secret_key, config) do
    with %ExHmac.Config{signature_name: signature_name} <- config,
         {signature, args} when not is_nil(signature) <- Keyword.pop(args, signature_name),
         my_signature <- sign(args, access_key, secret_key, config),
         true <- String.downcase(signature) == String.downcase(my_signature) do
      :ok
    else
      _ -> :signature_error
    end
  end

  ###
  def sign(args, access_key, secret_key, config) do
    args
    |> Callback.make_sign_string(access_key, secret_key, config)
    |> case do
      :default -> Signer.make_sign_string(args, access_key, secret_key, config)
      sign_string -> sign_string
    end
    |> do_sign(access_key, config)
  end

  def do_sign(sign_string, access_key, config) do
    %ExHmac.Config{hash_alg: hash_alg} = config

    with(
      contain_hmac? <- Util.contain_hmac?(hash_alg),
      hash_alg <- Util.prune_hash_alg(hash_alg),
      encode <- Callback.encode_hash_result(config)
    ) do
      Signer.do_sign(sign_string, hash_alg, {contain_hmac?, access_key}, encode)
    end
  end

  ###
  def gen_timestamp(config) do
    with precision <- Map.get(config, :precision) do
      Util.get_curr_ts(precision)
    end
  end

  def gen_nonce(config) do
    with nonce_len <- Map.get(config, :nonce_len) do
      Noncer.gen_nonce(nonce_len)
    end
  end
end
