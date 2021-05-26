defmodule Project.Hmac do
  # use ExHmac, key_name: :key, secret_name: :secret

  def fmt_errors(errors) do
    errors
  end

  def get_secret_key(key) do
    {key}
    "secret"
  end
end

defmodule Project do
  # import Project.Hmac

  # @decorate check_hmac()
  def sign_in(params) when is_map(params) or is_list(params) do
    :ok
  end

  def sign_in(username, passwd) when is_bitstring(username) and is_bitstring(passwd) do
    :ok
  end
end

defmodule ExHmacTest do
  use ExUnit.Case
  doctest ExHmac
end
