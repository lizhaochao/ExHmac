defmodule ExHmac.Config do
  @moduledoc """
  all configs' default unit is second.
  """

  @default_timestamp_offset 900
  @default_nonce_ttl 900
  @default_nonce_len 6

  @sha1 [:sha]
  @sha2 [:sha512, :sha384, :sha256, :sha224]
  @sha3 [:sha3_512, :sha3_384, :sha3_256, :sha3_224]
  @blake2 [:blake2b, :blake2s]
  @compatibility_only_hash [:md5]

  def hmac_hash_algs_prefix, do: "hmac_"

  def get_config(opts) when is_list(opts) do
    %{
      # time calculation
      precision: get(opts, :precision, :second),
      timestamp_offset: get(opts, :timestamp_offset, @default_timestamp_offset),
      nonce_len: get(opts, :nonce_len, @default_nonce_len),
      nonce_ttl: get(opts, :nonce_ttl, @default_nonce_ttl),
      # default name
      access_key_name: get(opts, :access_key_name, :access_key),
      secret_key_name: get(opts, :secret_key_name, :secret_key),
      signature_name: get(opts, :signature_name, :signature),
      timestamp_name: get(opts, :timestamp_name, :timestamp),
      nonce_name: get(opts, :nonce_name, :nonce),
      resp_succ_data_name: get(opts, :resp_succ_data_name, :data),
      resp_fail_data_name: get(opts, :resp_fail_data_name, :error),
      # other
      hash_alg: get(opts, :hash_alg, :sha256),
      warn: get(opts, :warn, true)
    }
  end

  ###
  def support_hash_algs, do: @sha1 ++ @sha2 ++ @sha3 ++ @blake2 ++ @compatibility_only_hash

  ###
  defp get(data, key, default), do: Keyword.get(data, key, default)
end
