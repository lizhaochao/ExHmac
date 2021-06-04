defmodule Lijiayou.Hmac do
  use ExHmac.Defhmac

  alias ExHmac.TestHelper

  def get_secret_key(access_key) do
    {access_key}
    TestHelper.get_test_secret_key()
  end
end

defmodule Lijiayou do
  import Lijiayou.Hmac

  defhmac sign_in(username, passwd, access_key, timestamp, nonce, signature) do
    {access_key, timestamp, nonce, signature}
    [username, passwd]
  end
end

defmodule DefhmacTest do
  use ExUnit.Case

  use ExHmac

  alias ExHmac.TestHelper

  test "ok" do
    with(
      username <- "ljy",
      passwd <- "123456",
      ts <- gen_timestamp(),
      nonce <- gen_nonce(),
      key <- TestHelper.get_test_access_key(),
      secret <- TestHelper.get_test_secret_key(),
      args <- [username: username, passwd: passwd, access_key: key, timestamp: ts, nonce: nonce],
      sig <- sign(args, key, secret),
      resp <- Lijiayou.sign_in(username, passwd, key, ts, nonce, sig),
      %{data: data} <- Map.new(resp)
    ) do
      assert [username, passwd] == data
    end
  end
end
