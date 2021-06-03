defmodule Lijiayou.Hmac do
  use ExHmac.Defhmac

  alias ExHmac.TestHelper

  def get_secret_by_key(access_key) do
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

  alias ExHmac.TestHelper

  test "ok" do
    username = "ljy"
    passwd = "123456"
    access_key = TestHelper.get_test_access_key()

    assert [username, passwd] ==
             Lijiayou.sign_in(
               username,
               passwd,
               access_key,
               1_622_742_887,
               "A1B2C3",
               "signature"
             )
  end
end
