defmodule ExHmac.Test do
  use ExHmac

  @access_key "access_key"
  @secret_key "secret_key"
  @error_code -1

  def get_key, do: @access_key
  def get_secret(_key), do: @secret_key

  def serialize({:ok, json_string}), do: json_string
  def serialize(params), do: params |> Map.new() |> Poison.encode() |> serialize()

  def deserialize({:ok, map}), do: map
  def deserialize(json_string), do: json_string |> Poison.decode() |> deserialize()

  def make_signature(params), do: sign(params, @access_key, @secret_key)
  def append_signature(params, signature), do: Keyword.new(params) ++ [signature: signature]

  def make_resp(code \\ @error_code) do
    with params <- make_res_params(code),
         signature <- make_signature(params),
         params <- append_signature(params, signature),
         resp <- serialize(params) do
      resp
    end
  end

  def make_res_params(code), do: [result: code, timestamp: gen_timestamp(), nonce: gen_nonce()]
end

defmodule Project do
  use ExHmac

  alias ExHmac.Test

  def sign_in(json_string) do
    with params <- Test.deserialize(json_string),
         access_key <- Test.get_key(),
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
  use ExHmac

  alias ExHmac.Test

  doctest ExHmac

  describe "ok" do
    test "params is keyword" do
      # 1. prepare req data
      with params <- make_req_params(),
           signature <- Test.make_signature(params),
           params <- Test.append_signature(params, signature),
           json_string <- Test.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
           # 3. process resp data
           res_params <- Test.deserialize(resp),
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
      with params <- make_req_params() |> Map.new(),
           signature <- Test.make_signature(params),
           params <- Test.append_signature(params, signature),
           json_string <- Test.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
           # 3. process resp data
           res_params <- Test.deserialize(resp),
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
      with params <- make_req_params(),
           signature <- Test.make_signature(any: "any"),
           params <- Test.append_signature(params, signature),
           json_string <- Test.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
           # 3. process resp data
           res_params <- Test.deserialize(resp),
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
      with params <- make_req_params(100, nil),
           signature <- Test.make_signature(params),
           params <- Test.append_signature(params, signature),
           json_string <- Test.serialize(params),
           # 2. invoke api
           resp <- Project.sign_in(json_string),
           # 3. process resp data
           res_params <- Test.deserialize(resp),
           access_key <- Test.get_key(),
           secret_key <- Test.get_secret(access_key),
           %{"result" => result} <- res_params do
        # 4. check resp
        assert :ok == check_hmac(res_params, access_key, secret_key)
        assert -1 == result
      end
    end

    test "same nonce request twice" do
      # TODO: impl Noncer
    end
  end

  ### Helper
  def make_req_params(timestamp \\ nil, nonce \\ nil) do
    # nested data
    with {:ok, b_value} <- Poison.encode(%{c: "c", d: "d"}),
         params <- [
           a: 1,
           b: b_value,
           timestamp: timestamp || gen_timestamp(),
           nonce: nonce || gen_nonce()
         ] do
      params
    end
  end
end
