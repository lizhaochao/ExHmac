defmodule ExHmac.Util do
  @moduledoc false

  alias ExHmac.Const

  @default_access_key_name Const.default_access_key_name()
  @default_secret_key_name Const.default_secret_key_name()
  @default_signature_name Const.default_signature_name()

  def to_atom() do
  end

  def get_user_opts(opts) when is_list(opts) do
    %{
      access_key_name: Keyword.get(opts, :access_key_name, @default_access_key_name),
      secret_key_name: Keyword.get(opts, :secret_key_name, @default_secret_key_name),
      signature_name: Keyword.get(opts, :secret_key_name, @default_signature_name),
      hash_alg: Keyword.get(opts, :hash_alg, :sha256)
    }
  end
end
