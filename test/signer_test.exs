defmodule SignerTest do
  use ExUnit.Case

  alias ExHmac.{Error, Signer, Util}

  @opts Util.get_user_opts([])

  test "sign" do
    with args <- [a: "a", b: [1, 2, 3]],
         access_key <- "access",
         secret_key <- "secret",
         %{hash_alg: hash_alg} <- @opts,
         expected <- "efc2ca04075c06e5234c4eb2c321aee4ea1a0c58fe5730d44f989e0d12f10154" do
      assert expected ==
               args
               |> Signer.make_sign_string(access_key, secret_key, @opts)
               |> Signer.do_sign(hash_alg)
    end
  end

  describe "make_sign_string/4" do
    test "ok" do
      with args <- [a: "a", b: [1, 2, 3]],
           access_key <- "access",
           secret_key <- "secret",
           expected <- "a=a&access_key=access&b=[1,2,3]&secret_key=secret" do
        assert expected == Signer.make_sign_string(args, access_key, secret_key, @opts)
      end
    end

    test "error" do
      [
        {%{}, 123, 456, []},
        {%{}, "abc", "efg", @opts},
        {[a: 1], 123, "efg", @opts},
        {[a: 1], "abc", 456, @opts},
        {[a: 1], "abc", "efg", []},
        {[a: 1], "abc", "efg", %{}}
      ]
      |> Enum.each(fn {args, access_key, secret_key, opts} ->
        assert_raise Error, fn ->
          Signer.make_sign_string(args, access_key, secret_key, opts)
        end
      end)
    end
  end

  describe "do_make_sign_string/3" do
    test "only string & atom" do
      with args <- [a: "a", b: true],
           access_key <- "access",
           secret_key <- "secret",
           expected <- "a=a&access_key=access&b=true&secret_key=secret" do
        maker = Signer.do_make_sign_string(args, access_key, secret_key)
        assert expected == maker.(:signature, :access_key, :secret_key)
      end
    end

    test "nested map" do
      with args <- [a: "a", b: %{c: "c", d: "d"}],
           access_key <- "access",
           secret_key <- "secret",
           expected <- "a=a&access_key=access&b={\"d\":\"d\",\"c\":\"c\"}&secret_key=secret" do
        maker = Signer.do_make_sign_string(args, access_key, secret_key)
        assert expected == maker.(:signature, :access_key, :secret_key)
      end
    end

    test "nested map -> list" do
      with args <- [a: "a", b: %{c: [1, 2, 3]}],
           access_key <- "access",
           secret_key <- "secret",
           expected <- "a=a&access_key=access&b={\"c\":[1,2,3]}&secret_key=secret" do
        maker = Signer.do_make_sign_string(args, access_key, secret_key)
        assert expected == maker.(:signature, :access_key, :secret_key)
      end
    end
  end

  describe "to_json_string/1" do
    test "map" do
      assert "{}" == Signer.to_json_string(%{})
      assert "{\"a\":1}" == Signer.to_json_string(%{a: 1})
      assert "{\"a\":\"b\"}" == Signer.to_json_string(%{"a" => "b"})
      assert "{\"a\":true}" == Signer.to_json_string(%{"a" => true})
      # nested map/list
      assert "{\"a\":{\"b\":false}}" == Signer.to_json_string(%{"a" => %{"b" => false}})
      assert "{\"a\":[1,2,3]}" == Signer.to_json_string(%{"a" => [1, 2, 3]})
    end

    test "list" do
      assert "[]" == Signer.to_json_string([])
      assert "[1,\"a\",true]" == Signer.to_json_string([1, "a", true])
      # nested map/list
      assert "[{\"a\":1}]" == Signer.to_json_string([%{a: 1}])
      assert "[[1,2],[\"a\",\"b\"]]" == Signer.to_json_string([[1, 2], ["a", "b"]])
    end

    test "atom/string/integer/float/boolean" do
      assert "ok" == Signer.to_json_string(:ok)
      assert "ok" == Signer.to_json_string("ok")
      assert "1" == Signer.to_json_string(1)
      assert "1.1" == Signer.to_json_string(1.1)
      assert "true" == Signer.to_json_string(true)
      assert "false" == Signer.to_json_string(false)
    end

    test "error - tuple" do
      assert_raise Error, fn ->
        Signer.to_json_string({1, 2, 3})
      end
    end
  end

  describe "do_sign 2/3" do
    test "ok" do
      assert "61964c398979755b435ffe9981bd175c8a3e7daaf09ffd52422294b1a1e76f09" ==
               Signer.do_sign("ljy", :sha256)

      assert "76d3a8719054c21f6944799065896f9143ab56870dbe11586d41aaa7c9b3df7c" ==
               Signer.do_sign("ljy", :sha256, "key")
    end

    test "not support hash alg" do
      assert_raise Error, fn ->
        Signer.do_sign("ljy", :sha224)
      end
    end
  end

  describe "hash alg" do
    test "sha512" do
      assert "cf7714c083ef44353f89a8e868565105b16512e818d506fa1774229caac2bc19826f8525d8bcb7e8c0348e6da7748042cd03f7c359c55745449a7fc8eeda2dd9" ==
               Signer.hash("lijiayou", :sha512)
    end

    test "sha256" do
      assert "7efcc5df369912858013766d3654b625cd4f4c45785d0c1053d1c631903fa926" ==
               Signer.hash("lijiayou", :sha256)
    end

    test "md5" do
      assert "345fd9af7881b9d1c5f950fcc8e1c8b0" ==
               Signer.hash("lijiayou", :md5)
    end
  end
end
