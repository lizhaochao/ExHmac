defmodule AuthCenter.Client.Hmac do
  use ExHmac,
    hash_alg: :sha512,
    warn: false,
    nonce_len: 20

  def encode_hash_result(hash_result), do: Base.encode16(hash_result, case: :upper)
end

defmodule AuthCenter.Client do
  use ExUnit.Case
  import AuthCenter.Client.Hmac
  alias ExHmac.TestHelper
  alias AuthCenter.Server

  @access_key TestHelper.get_test_access_key()
  @secret_key TestHelper.get_test_secret_key()
  @username "ljy"
  @passwd "funny"

  def get_username, do: @username
  def get_passwd, do: @passwd

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

  def start_request do
    with access_key <- @access_key,
         timestamp <- gen_timestamp(),
         nonce <- gen_nonce(),
         signature <- make_signature(timestamp, nonce) do
      resp = Server.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
      %{username: username, passwd: passwd} = resp = Map.new(resp)
      assert 5 == map_size(resp)
      assert @username == username
      assert @passwd == passwd
    end
  end
end

### ### ### ### ### ### ### ### ### ###

defmodule AuthCenter.Server.Hmac do
  use ExHmac,
    hash_alg: :sha512,
    warn: false,
    nonce_len: 20,
    get_secret_key_fun_name: :get_secret_by_key

  alias ExHmac.TestHelper
  alias ExHmac.Repo

  def pre_hook(args), do: args
  def post_hook(resp), do: resp

  def get_access_key(args) do
    Keyword.get(args, :access_key, TestHelper.get_test_access_key())
  end

  def get_secret_by_key(access_key) do
    {access_key}
    TestHelper.get_test_secret_key()
  end

  def check_nonce(nonce, curr_ts, nonce_freezing_secs, precision) do
    # clean unused warnings
    {nonce, curr_ts, nonce_freezing_secs, precision}

    arrived_at =
      fn repo ->
        value = Map.get(repo, nonce)
        repo = Map.put(repo, nonce, 0)
        {value, repo}
      end
      |> Repo.get()

    if is_nil(arrived_at), do: :ok, else: :invalid_nonce
  end

  def make_sign_string(args, access_key, secret_key) do
    to_json_string = fn term ->
      case term do
        term when is_bitstring(term) -> term
        term when is_atom(term) -> Atom.to_string(term)
        term -> term |> Poison.encode() |> elem(1)
      end
    end

    args
    |> Keyword.drop([:signature])
    |> Keyword.put(:access_key, access_key)
    |> Keyword.put(:secret_key, secret_key)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> "#{k}=#{to_json_string.(v)}" end)
    |> Enum.join("&")
  end

  def encode_hash_result(hash_result) do
    Base.encode16(hash_result, case: :upper)
  end

  def fmt_resp(resp) do
    case resp do
      [username, passwd] -> %{username: username, passwd: passwd}
      err when is_atom(err) -> %{result: 10_001, error_msg: to_string(err)}
      resp -> resp
    end
  end
end

defmodule AuthCenter.Server do
  use AuthCenter.Server.Hmac

  @decorate check_hmac()
  def sign_in(username, passwd, access_key, timestamp, nonce, signature) do
    # just clean unused warnings
    {access_key, timestamp, nonce, signature}
    # result
    [username, passwd]
  end
end

### ### ### ### ### ### ### ### ### ###

defmodule ExHmacDecoratorTest do
  ### ### ### ### ### !!! NOTICE !!! ### ### ### ### ###
  ###       If Failed, Run The Following Command:    ###
  ###                mix test --seed 0               ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  use ExUnit.Case

  use ExHmac
  alias ExHmac.TestHelper
  alias ExHmac.{Noncer, Repo}
  alias AuthCenter.{Client, Server}

  setup_all do
    Repo.init()
    :ok
  end

  @username Client.get_username()
  @passwd Client.get_passwd()
  @access_key TestHelper.get_test_access_key()

  test "ok" do
    with(
      n <- 10,
      tasks <- Enum.map(1..n, fn _ -> Task.async(fn -> Client.start_request() end) end),
      timeout <- 10_000,
      _ <- Task.await_many(tasks, timeout),
      %{nonces: nonces, mins: mins, counts: counts, shards: shards} <- Noncer.all()
    ) do
      assert n == length(Map.keys(nonces))
      assert 1 == length(Map.keys(counts))
      assert 1 == length(Map.keys(shards))
      assert 1 == length(MapSet.to_list(mins))

      assert MapSet.to_list(mins) == Map.keys(counts)
      assert MapSet.to_list(mins) == Map.keys(shards)
      assert MapSet.new(Map.keys(nonces)) == MapSet.new(hd(Map.values(shards)))

      assert n == hd(Map.values(counts))
    end
  end

  describe "error" do
    test "error" do
      with access_key <- nil,
           timestamp <- gen_timestamp(),
           nonce <- gen_nonce(),
           signature <- Client.make_signature(timestamp, nonce) do
        resp = Server.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
        %{error_msg: error_msg} = resp = Map.new(resp)
        assert 2 == map_size(resp)
        assert to_string(:get_access_key_error) == error_msg
      end
    end

    test "error with hmac" do
      with access_key <- "nil",
           timestamp <- gen_timestamp(),
           nonce <- gen_nonce(),
           signature <- Client.make_signature(timestamp, nonce) do
        resp = Server.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
        %{error_msg: error_msg} = resp = Map.new(resp)
        assert 5 == map_size(resp)
        assert to_string(:signature_error) == error_msg
      end
    end

    test "error - use same nonce request twice" do
      with access_key <- @access_key,
           timestamp <- gen_timestamp(),
           nonce <- gen_nonce(),
           signature <- Client.make_signature(timestamp, nonce) do
        # first
        resp = Server.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
        %{username: username, passwd: passwd} = resp = Map.new(resp)
        assert 5 == map_size(resp)
        assert @username == username
        assert @passwd == passwd

        # second
        resp2 = Server.sign_in(@username, @passwd, access_key, timestamp, nonce, signature)
        %{error_msg: error_msg} = resp2 = Map.new(resp2)
        assert 5 == map_size(resp2)
        assert to_string(:invalid_nonce) == error_msg
      end
    end
  end
end
