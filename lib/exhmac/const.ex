defmodule ExHmac.Const do
  @moduledoc false

  def default_access_key_name, do: :access_key
  def default_secret_key_name, do: :secret_key
  def default_signature_name, do: :signature
  def default_nonce_name, do: :nonce
  def default_timestamp_name, do: :timestamp

  def default_timestamp_offset_seconds, do: 900
  def default_nonce_ttl, do: 900
end
