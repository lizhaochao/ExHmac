defmodule ExHmac.Util do
  @moduledoc false

  alias ExHmac.Const

  @default_access_key_name Const.default_access_key_name()
  @default_secret_key_name Const.default_secret_key_name()
  @default_signature_name Const.default_signature_name()
  @default_timestamp_offset_seconds Const.default_timestamp_offset_seconds()
  @default_nonce_ttl Const.default_nonce_ttl()

  def to_atom() do
  end

  def get_user_opts(opts) when is_list(opts) do
    %{
      timestamp_offset_seconds:
        Keyword.get(opts, :timestamp_offset_seconds, @default_timestamp_offset_seconds),
      nonce_ttl: Keyword.get(opts, :nonce_ttl, @default_nonce_ttl),
      access_key_name: Keyword.get(opts, :access_key_name, @default_access_key_name),
      secret_key_name: Keyword.get(opts, :secret_key_name, @default_secret_key_name),
      signature_name: Keyword.get(opts, :secret_key_name, @default_signature_name),
      hash_alg: Keyword.get(opts, :hash_alg, :sha256)
    }
  end
end
