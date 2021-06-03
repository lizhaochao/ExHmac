defmodule ExHmac.Config do
  @moduledoc """
  all configs' default unit is second.
  """

  @default_timestamp_offset_secs 900
  @default_nonce_ttl_secs 900
  @default_nonce_len 6
  @default_precision :second
  @default_collect_interval_milli 60_000
  @default_search_mins_len 1

  @default_gc_should_warn_count 20_000

  @sha1 [:sha]
  @sha2 [:sha512, :sha384, :sha256, :sha224]
  @sha3 [:sha3_512, :sha3_384, :sha3_256, :sha3_224]
  @blake2 [:blake2b, :blake2s]
  @compatibility_only_hash [:md5]

  def hmac_hash_algs_prefix, do: "hmac_"

  def get_search_mins_len, do: @default_search_mins_len

  def gc_should_warn_count,
    do: Application.get_env(:exhmac, :gc_should_warn_count, @default_gc_should_warn_count)

  def get_collect_interval_milli,
    do: Application.get_env(:exhmac, :collect_interval_milli, @default_collect_interval_milli)

  def get_nonce_ttl_secs,
    do: Application.get_env(:exhmac, :nonce_ttl_secs, @default_nonce_ttl_secs)

  def get_timestamp_offset_secs,
    do: Application.get_env(:exhmac, :timestamp_offset_secs, @default_timestamp_offset_secs)

  def get_precision,
    do: Application.get_env(:exhmac, :precision, @default_precision)

  def get_config(opts) when is_list(opts) do
    %{
      # time calculation
      nonce_len: get(opts, :nonce_len, @default_nonce_len),
      # default name
      access_key_name: get(opts, :access_key_name, :access_key),
      secret_key_name: get(opts, :secret_key_name, :secret_key),
      signature_name: get(opts, :signature_name, :signature),
      timestamp_name: get(opts, :timestamp_name, :timestamp),
      nonce_name: get(opts, :nonce_name, :nonce),
      resp_succ_data_name: get(opts, :resp_succ_data_name, :data),
      resp_fail_data_name: get(opts, :resp_fail_data_name, :error),
      get_secret_key_function_name: get(opts, :get_secret_key_function_name, :get_secret_key),
      # other
      hash_alg: get(opts, :hash_alg, :sha256),
      warn: get(opts, :warn, true),
      #
      impl_m: nil
    }
  end

  ###
  def support_hash_algs, do: @sha1 ++ @sha2 ++ @sha3 ++ @blake2 ++ @compatibility_only_hash

  ###
  defp get(data, key, default), do: Keyword.get(data, key, default)
end
