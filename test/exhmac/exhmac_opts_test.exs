defmodule Server.Hmac do
  use ExHmac,
    precision: :millisecond,
    access_key_name: :key,
    secret_key_name: :secret,
    signature_name: :sig,
    timestamp_name: :ts,
    nonce_name: :once,
    hash_alg: :hmac_sha256,
    nonce_len: 20

  def get_access_key_name, do: :key
  def get_signature_name, do: :sig
  def get_timestamp_name, do: :ts
  def get_nonce_name, do: :once
end

defmodule Server do
  import Server.Hmac

  alias ExHmac.Opts.Test
  alias ExHmac.TestHelper

  def sign_in(json_string) do
    with params <- TestHelper.deserialize(json_string),
         access_key <- Test.get_key(params),
         secret_key <- Test.get_secret(access_key),
         :ok <- check_hmac(params, access_key, secret_key),
         ok_code <- 0 do
      Test.make_resp(ok_code)
    else
      _ -> Test.make_resp()
    end
  end
end

defmodule ExHmacOptsTest do
  use ExUnit.Case

  import Server.Hmac

  alias ExHmac.Opts.Test
  alias ExHmac.TestHelper
  alias ExHmac.Repo

  setup_all do
    Repo.init()
    :ok
  end

  test "ok" do
    # 1. prepare req data
    with req_params <- Test.make_req_params() |> Map.new(),
         signature <- Test.make_signature(req_params),
         req_params <- Test.put_signature(req_params, signature),
         json_string <- TestHelper.serialize(req_params),
         # 2. invoke api
         resp <- Server.sign_in(json_string),
         # 3. process resp data
         res_params <- TestHelper.deserialize(resp),
         access_key <- Test.get_key(),
         secret_key <- Test.get_secret(access_key),
         %{"result" => result} <- res_params do
      # 4. check resp
      assert :ok == check_hmac(res_params, access_key, secret_key)
      assert 0 == result
    end
  end
end

defmodule ExHmac.Opts.Test do
  import Server.Hmac

  alias ExHmac.TestHelper

  @access_key_name get_access_key_name()
  @signature_name get_signature_name()
  @timestamp_name get_timestamp_name()
  @nonce_name get_nonce_name()
  @access_key TestHelper.get_test_access_key()
  @secret_key TestHelper.get_test_secret_key()
  @error_code TestHelper.get_error_code()

  def get_key, do: @access_key
  def get_key(%{"key" => access_key}), do: access_key
  def get_secret(_key), do: @secret_key

  def make_signature(params), do: sign(params, @access_key, @secret_key)

  def put_signature(params, signature) do
    params |> Keyword.new() |> Keyword.put(@signature_name, signature)
  end

  def make_resp(code \\ @error_code) do
    with params <- make_res_params(code),
         signature <- make_signature(params),
         params <- put_signature(params, signature),
         resp <- TestHelper.serialize(params) do
      resp
    end
  end

  def make_req_params(timestamp \\ nil, nonce \\ nil) do
    # nested data
    with {:ok, b_value} <- TestHelper.to_json_string(%{c: "c", d: "d"}),
         params <- [
           a: 1,
           b: b_value
         ] do
      params
      |> Keyword.put(@access_key_name, @access_key)
      |> Keyword.put(@timestamp_name, timestamp || gen_timestamp())
      |> Keyword.put(@nonce_name, nonce || gen_nonce())
    end
  end

  def make_res_params(code) do
    [result: code]
    |> Keyword.put(@timestamp_name, gen_timestamp())
    |> Keyword.put(@nonce_name, gen_nonce())
  end
end
