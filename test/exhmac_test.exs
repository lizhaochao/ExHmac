defmodule ExHmac.Test.Util do
  @moduledoc false

  use ExHmac

  @access_key "access_key"
  @secret_key "secret_key"

  def get_key, do: @access_key
  def get_secret(_key), do: @secret_key

  def serialize({:ok, json_string}), do: json_string
  def serialize(params), do: params |> Enum.into(%{}) |> Poison.encode() |> serialize()

  def deserialize({:ok, map}), do: map
  def deserialize(json_string), do: json_string |> Poison.decode() |> deserialize()

  def make_signature(params), do: sign(params, @access_key, @secret_key)
  def append_signature(params, signature), do: params ++ [signature: signature]

  def make_resp(code \\ -1) do
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

  alias ExHmac.Test.Util

  def sign_in(json_string) do
    with params <- Util.deserialize(json_string),
         access_key <- Util.get_key(),
         secret_key <- Util.get_secret(access_key),
         :ok <- check_hmac(params, access_key, secret_key),
         ok_code <- 0 do
      Util.make_resp(ok_code)
    else
      _ -> Util.make_resp()
    end
  end
end

defmodule ExHmacTest do
  use ExUnit.Case
  doctest ExHmac

  use ExHmac

  alias ExHmac.Test.Util

  test "ok" do
    # 1. prepare req data
    with params <- make_req_params(),
         signature <- Util.make_signature(params),
         params <- Util.append_signature(params, signature),
         json_string <- Util.serialize(params),
         # 2. invoke api
         resp <- Project.sign_in(json_string),
         # 3. process resp data
         res_params <- Util.deserialize(resp),
         access_key <- Util.get_key(),
         secret_key <- Util.get_secret(access_key) do
      # 4. check resp
      assert :ok == check_hmac(res_params, access_key, secret_key)
    end
  end

  def make_req_params do
    # nested data
    with {:ok, b_value} <- Poison.encode(%{c: "c", d: "d"}),
         params <- [a: 1, b: b_value, timestamp: gen_timestamp(), nonce: gen_nonce()] do
      params
    end
  end
end
