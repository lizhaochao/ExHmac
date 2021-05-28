defmodule ExHmac.Const do
  @moduledoc false

  def default_access_key_name, do: :access_key
  def default_secret_key_name, do: :secret_key
  def default_signature_name, do: :signature
  def default_nonce_name, do: :nonce
  def default_timestamp_name, do: :timestamp

  def default_timestamp_offset_seconds, do: 900
  def default_nonce_ttl, do: 900

  def support_hash_algs do
    with sha1 <- [:sha],
         sha2 <- [:sha512, :sha384, :sha256, :sha224],
         sha3 <- [:sha3_512, :sha3_384, :sha3_256, :sha3_224],
         blake2 <- [:blake2b, :blake2s],
         compatibility_only_hash <- [:md5] do
      sha1 ++ sha2 ++ sha3 ++ blake2 ++ compatibility_only_hash
    end
  end
end
