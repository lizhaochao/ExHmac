defmodule AuthCenter.Hmac do
  use ExHmac,
    hash_alg: :sha512,
    warn: false,
    nonce_len: 20,
    get_secret_key_function_name: :get_secret_by_key

  alias ExHmac.TestHelper

  def get_secret_by_key(access_key) do
    {access_key}
    TestHelper.get_test_secret_key()
  end

  def fmt_resp(resp) do
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
  alias ExHmac.TestHelper
  alias ExHmac.Noncer.Worker, as: NoncerWorker

  ### ### ### ### ### !!! NOTICE !!! ### ### ### ### ###
  ###       If Failed, Run The Following Command:    ###
  ###                mix test --seed 0               ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  @access_key TestHelper.get_test_access_key()
  @secret_key TestHelper.get_test_secret_key()
  @username "ljy"
  @passwd "funny"

  describe "ok" do
    test "request x times - ok" do
      with(
        times <- 3,
        _ <- Enum.each(1..times, fn _ -> request() end),
        %{nonces: nonces, mins: mins, count: count, shards: shards} <- NoncerWorker.all()
      ) do
        assert times == length(Map.keys(nonces))
        assert 1 == length(Map.keys(count))
        assert 1 == length(Map.keys(shards))
        assert 1 == length(mins)

        assert mins == Map.keys(count)
        assert mins == Map.keys(shards)
        assert MapSet.new(Map.keys(nonces)) == MapSet.new(hd(Map.values(shards)))

        assert times == hd(Map.values(count))
      end
    end

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
  end

  describe "error" do
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

    test "error - use same nonce request twice" do
      with access_key <- @access_key,
           timestamp <- gen_timestamp(),
           nonce <- gen_nonce(),
           signature <- make_signature(timestamp, nonce) do
        # first
        resp = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
        %{username: username, passwd: passwd} = resp = Map.new(resp)
        assert 5 == map_size(resp)
        assert @username == username
        assert @passwd == passwd

        # second
        resp2 = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
        %{error_msg: error_msg} = resp2 = Map.new(resp2)
        assert 5 == map_size(resp2)
        assert to_string(:invalid_nonce) == error_msg
      end
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

  def request do
    with access_key <- @access_key,
         timestamp <- gen_timestamp(),
         nonce <- gen_nonce(),
         signature <- make_signature(timestamp, nonce) do
      resp = AuthCenter.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
      assert 5 == length(resp)
    end
  end
end
