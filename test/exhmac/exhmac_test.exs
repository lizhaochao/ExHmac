defmodule Project.Hmac do
  use ExHmac, warn: false
end

defmodule Project do
  import Project.Hmac

  alias ExHmac.Test
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

defmodule ExHmacTest do
  use ExUnit.Case

  import Project.Hmac

  alias ExHmac.Test
  alias ExHmac.TestHelper
  alias ExHmac.Repo

  setup_all do
    Repo.init()
    :ok
  end

  doctest ExHmac

  describe "ok" do
    test "params is keyword" do
      # 1. prepare req data
      with params <- Test.make_req_params(),
           signature <- Test.make_signature(params),
           params <- Test.append_signature(params, signature),
           json_string <- TestHelper.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
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

    test "params is map" do
      # 1. prepare req data
      with params <- Test.make_req_params() |> Map.new(),
           signature <- Test.make_signature(params),
           params <- Test.append_signature(params, signature),
           json_string <- TestHelper.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
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

  describe "error" do
    test "signature" do
      # 1. prepare req data
      with params <- Test.make_req_params(),
           signature <- Test.make_signature(any: "any"),
           params <- Test.append_signature(params, signature),
           json_string <- TestHelper.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
           # 3. process resp data
           res_params <- TestHelper.deserialize(resp),
           access_key <- Test.get_key(),
           secret_key <- Test.get_secret(access_key),
           %{"result" => result} <- res_params do
        # 4. check resp
        assert :ok == check_hmac(res_params, access_key, secret_key)
        assert -1 == result
      end
    end

    test "timestamp" do
      # 1. prepare req data
      with params <- Test.make_req_params(gen_timestamp() * 1000, nil),
           signature <- Test.make_signature(params),
           params <- Test.append_signature(params, signature),
           json_string <- TestHelper.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
           # 3. process resp data
           res_params <- TestHelper.deserialize(resp),
           access_key <- Test.get_key(),
           secret_key <- Test.get_secret(access_key),
           %{"result" => result} <- res_params do
        # 4. check resp
        assert :ok == check_hmac(res_params, access_key, secret_key)
        assert -1 == result
      end
    end
  end
end

defmodule ExHmac.Test do
  import Project.Hmac

  alias ExHmac.TestHelper

  @access_key TestHelper.get_test_access_key()
  @secret_key TestHelper.get_test_secret_key()
  @error_code TestHelper.get_error_code()

  def get_key, do: @access_key
  def get_key(%{"access_key" => access_key}), do: access_key
  def get_secret(_key), do: @secret_key

  def make_signature(params), do: sign(params, @access_key, @secret_key)
  def append_signature(params, signature), do: Keyword.new(params) ++ [signature: signature]

  def make_resp(code \\ @error_code) do
    with params <- make_res_params(code),
         signature <- make_signature(params),
         params <- append_signature(params, signature),
         resp <- TestHelper.serialize(params) do
      resp
    end
  end

  def make_req_params(timestamp \\ nil, nonce \\ nil) do
    # nested data
    with {:ok, b_value} <- TestHelper.to_json_string(%{c: "c", d: "d"}),
         params <- [
           access_key: @access_key,
           a: 1,
           b: b_value,
           timestamp: timestamp || gen_timestamp(),
           nonce: nonce || gen_nonce()
         ] do
      params
    end
  end

  def make_res_params(code) do
    [
      result: code,
      timestamp: gen_timestamp(),
      nonce: gen_nonce()
    ]
  end
end
