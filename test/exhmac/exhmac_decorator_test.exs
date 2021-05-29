defmodule AuthCenter.Hmac do
  use ExHmac,
    hash_alg: :sha512,
    warn: false,
    nonce_len: 20,
    get_secret_key_function_name: :get_secret_by_key,
    format_resp_function_name: :format_resp

  def get_secret_by_key(access_key) do
    {access_key}
    "test_secret_key"
  end

  def format_resp(resp) do
    case resp do
      [username, passwd] -> %{username: username, passwd: passwd}
      err when is_atom(err) -> %{result: 10_001, error_msg: to_string(err)}
      resp -> resp
    end
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
      %{username: username, passwd: passwd} = resp = Map.new(resp)
      assert 5 == map_size(resp)
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
      %{error_msg: error_msg} = resp = Map.new(resp)
      assert 5 == map_size(resp)
      assert to_string(:signature_error) == error_msg
    end
  end

  test "error" do
    with access_key <- nil,
         timestamp <- gen_timestamp(),
         nonce <- gen_nonce(),
         signature <- make_signature(timestamp, nonce) do
      resp = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
      %{error_msg: error_msg} = resp = Map.new(resp)
      assert 2 == map_size(resp)
      assert to_string(:access_key_error) == error_msg
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
