defmodule AuthCenter.Hmac do
  use ExHmac.Decorator,
    hash_alg: :sha512,
    warn: false,
    nonce_len: 20

  def get_secret_key(access_key) do
    {access_key}
    "test_secret_key"
  end
end

defmodule AuthCenter do
  use AuthCenter.Hmac

  @decorate check_hmac()
  def sign_in(username, passwd, access_key, timestamp, nonce, signature) do
    # just clean unused warnings
    {access_key, timestamp, nonce, signature}
    # result
    [username, passwd]
  end
end

defmodule ExHmacDecoratorTest do
  use ExUnit.Case
  import AuthCenter.Hmac

  @access_key "test_access_key"
  @secret_key "test_secret_key"
  @username "ljy"
  @passwd "funny"

  test "ok" do
    with access_key <- @access_key,
         timestamp <- gen_timestamp(),
         nonce <- gen_nonce(),
         signature <- make_signature(timestamp, nonce) do
      resp = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
      %{data: [username, passwd]} = resp = Map.new(resp)
      assert 4 == map_size(resp)
      assert @username == username
      assert @passwd == passwd
    end
  end

  test "error with hmac" do
    with access_key <- "nil",
         timestamp <- gen_timestamp(),
         nonce <- gen_nonce(),
         signature <- make_signature(timestamp, nonce) do
      resp = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
      %{error: error} = resp = Map.new(resp)
      assert 4 == map_size(resp)
      assert :signature_error == error
    end
  end

  test "error" do
    with access_key <- nil,
         timestamp <- gen_timestamp(),
         nonce <- gen_nonce(),
         signature <- make_signature(timestamp, nonce) do
      resp = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
      %{error: error} = resp = Map.new(resp)
      assert 1 == map_size(resp)
      assert :access_key_error == error
    end
  end

  ### Helper
  def make_signature(timestamp \\ nil, nonce \\ nil) do
    [
      username: @username,
      passwd: @passwd,
      timestamp: timestamp || gen_timestamp(),
      nonce: nonce || gen_nonce()
    ]
    |> sign(@access_key, @secret_key)
  end
end
