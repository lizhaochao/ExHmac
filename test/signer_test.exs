defmodule SignerTest do
  use ExUnit.Case

  alias ExHmac.{Config, Error, Signer}

  @config Config.get_config([])

  test "sign" do
    with args <- [a: "a", b: [1, 2, 3]],
         access_key <- "access",
         secret_key <- "secret",
         %{hash_alg: hash_alg} <- @config,
         expected <- "efc2ca04075c06e5234c4eb2c321aee4ea1a0c58fe5730d44f989e0d12f10154" do
      assert expected ==
               args
               |> Signer.make_sign_string(access_key, secret_key, @config)
               |> Signer.do_sign(hash_alg)
    end
  end

  describe "make_sign_string/4" do
    test "ok" do
      with args <- [a: "a", b: [1, 2, 3]],
           access_key <- "access",
           secret_key <- "secret",
           expected <- "a=a&access_key=access&b=[1,2,3]&secret_key=secret" do
        assert expected == Signer.make_sign_string(args, access_key, secret_key, @config)
      end
    end

    test "error" do
      [
        {%{}, 123, 456, []},
        {%{}, "abc", "efg", @config},
        {[a: 1], 123, "efg", @config},
        {[a: 1], "abc", 456, @config},
        {[a: 1], "abc", "efg", []}
      ]
      |> Enum.each(fn {args, access_key, secret_key, config} ->
        assert_raise Error, fn ->
          Signer.make_sign_string(args, access_key, secret_key, config)
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
        Signer.do_sign("ljy", :md4)
      end
    end
  end

  describe "hash alg" do
    test "sha1" do
      assert "7165c23be7906058da8969c4593711ea77162490" ==
               Signer.hash("lijiayou", :sha)
    end

    test "sha2" do
      assert "cf7714c083ef44353f89a8e868565105b16512e818d506fa1774229caac2bc19826f8525d8bcb7e8c0348e6da7748042cd03f7c359c55745449a7fc8eeda2dd9" ==
               Signer.hash("lijiayou", :sha512)

      assert "18fe29e6ecc120d223b60276b57ae873bb44efc84d376ca1a897d0c6b4b53b646963551e310349279a108293d5b5d543" ==
               Signer.hash("lijiayou", :sha384)

      assert "7efcc5df369912858013766d3654b625cd4f4c45785d0c1053d1c631903fa926" ==
               Signer.hash("lijiayou", :sha256)

      assert "039b947fa2519308e05d55670337f062805e6a6cc44d72797e998992" ==
               Signer.hash("lijiayou", :sha224)
    end

    test "sha3" do
      assert "d30fd67d28150914e407ee1d3c290870c43a78a1a9567d025e2ae5d0cad89a97ce849e8d38aa12e271e2838a1b894e24b95d6492a833119256fb5ee3bbad7cc6" ==
               Signer.hash("lijiayou", :sha3_512)

      assert "49620502f1e3d12dc68c4d021f3d815853b3b144d905be11793cfd1390c242f4bde36bbe760d59de8645e9125d2a32fa" ==
               Signer.hash("lijiayou", :sha3_384)

      assert "7b5286188f67f199272b8601a5982c55c55dc088b7406df9621318d63383198b" ==
               Signer.hash("lijiayou", :sha3_256)

      assert "dadba065d261da5e8f64a107c95663c6c098ea71bc5d676a2f47429a" ==
               Signer.hash("lijiayou", :sha3_224)
    end

    test "blake2" do
      assert "0bbed52656d0e8831639586d87309dc35855455fb27e2c8fcb2ddb9f55bebe9967b863ddecb5ffede546db40304270e5a314351681686043d0365926e854d2dd" ==
               Signer.hash("lijiayou", :blake2b)

      assert "2fd6e5b5ad925e7a2e4d9413cd585137288601886b1d4ee60911f5f6226b0ff0" ==
               Signer.hash("lijiayou", :blake2s)
    end

    test "compatibility_only_hash" do
      assert "345fd9af7881b9d1c5f950fcc8e1c8b0" ==
               Signer.hash("lijiayou", :md5)
    end
  end
end
