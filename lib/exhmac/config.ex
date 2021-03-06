defmodule ExHmac.Config do
  @moduledoc false

  alias ExHmac.Repo

  @default_timestamp_offset_secs 900
  @default_nonce_freezing_secs 900
  @default_nonce_len 6
  @default_precision :second

  @default_gc_interval_milli 60_000
  @default_search_mins_len 1
  @default_gc_warn_count 20_000
  @default_disable_noncer false

  @sha1 [:sha]
  @sha2 [:sha512, :sha384, :sha256, :sha224]
  @sha3 [:sha3_512, :sha3_384, :sha3_256, :sha3_224]
  @blake2 [:blake2b, :blake2s]
  @compatibility_only_hash [:md5]

  defstruct [
    # time calculation
    precision: @default_precision,
    nonce_freezing_secs: @default_nonce_freezing_secs,
    timestamp_offset_secs: @default_timestamp_offset_secs,
    # default name
    access_key_name: :access_key,
    secret_key_name: :secret_key,
    signature_name: :signature,
    timestamp_name: :timestamp,
    nonce_name: :nonce,
    resp_succ_data_name: :data,
    resp_fail_data_name: :error,
    get_access_key_fun_name: :get_access_key,
    get_secret_key_fun_name: :get_secret_key,
    encode_hash_result_fun_name: :encode_hash_result,
    make_sign_string_fun_name: :make_sign_string,
    #
    nonce_len: @default_nonce_len,
    hash_alg: :sha256,
    warn: true,
    #
    impl_m: nil
  ]

  def hmac_hash_alg_prefix, do: "hmac_"
  def get_search_mins_len, do: @default_search_mins_len

  ###
  def get_gc_log_callback,
    do: Application.get_env(:exhmac, :gc_log_callback, nil)

  def get_gc_warn_count,
    do: Application.get_env(:exhmac, :gc_warn_count, @default_gc_warn_count)

  def get_gc_interval_milli,
    do: Application.get_env(:exhmac, :gc_interval_milli, @default_gc_interval_milli)

  def get_disable_noncer,
    do: Application.get_env(:exhmac, :disable_noncer, @default_disable_noncer)

  ###
  def get_nonce_freezing_secs,
    do: double_get(:nonce_freezing_secs, @default_nonce_freezing_secs)

  def get_precision,
    do: double_get(:precision, @default_precision)

  ###
  def get_config(opts) when is_list(opts),
    do: struct(__MODULE__, opts)

  ###
  def support_hash_algs,
    do: @sha1 ++ @sha2 ++ @sha3 ++ @blake2 ++ @compatibility_only_hash

  ###
  defp double_get(key, default) do
    fun = fn repo ->
      value = get_in(repo, [:config, key])
      {value, repo}
    end

    Repo.get(fun) || Application.get_env(:exhmac, key, default)
  end
end
