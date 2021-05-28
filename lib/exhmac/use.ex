defmodule ExHmac.Use do
  @moduledoc false

  alias ExHmac.Config

  @doc """
    args type: map, keyword, multi args
    check timestamp, can custom impl
    check nonce, can custom impl

    2. make args (keyword type)
    3. check timestamp (1.get 2.check)
    4. check nonce (1.get 2.check)
    5. make sign string (1.get access key 2.get secret key 3.make)
    6. sign
  """
  defmacro __using__(_opts) do
    :ok
  end

  ###
  def make_args(arg_names, arg_values) when is_list(arg_names) and is_list(arg_values) do
    [a: 1, b: 2]
  end

  #  def get_access_key(args, opts) when is_list(args) and is_list(opts) do
  #    with key_name when not is_nil(key_name) <-
  #           Keyword.get(opts, :key_name, @default_access_key_name),
  #         access_key when is_bitstring(access_key) <- Keyword.get(args, key_name, nil) do
  #      access_key
  #    else
  #      _ -> "get access key error"
  #    end
  #  end

  def get_secret_key(callback, access_key)
      when is_function(callback) and is_bitstring(access_key) do
    callback.(access_key)
  end
end
