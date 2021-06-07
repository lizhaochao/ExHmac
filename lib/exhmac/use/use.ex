defmodule ExHmac.Use do
  @moduledoc false

  alias ExHmac.{Config, Util}
  alias ExHmac.Core

  defmacro __using__(opts) do
    config = opts |> Config.get_config() |> Macro.escape()

    quote do
      def check_hmac(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             config <- unquote(config) |> Core.put_impl_m(__MODULE__) |> Core.save_config(),
             :ok <- Core.check_timestamp(args, config),
             :ok <- Core.check_nonce(args, config),
             :ok <- Core.check_signature(args, access_key, secret_key, config) do
          :ok
        else
          err -> err
        end
      end

      def sign(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             config <- unquote(config) |> Core.put_impl_m(__MODULE__) |> Core.save_config() do
          Core.sign(args, access_key, secret_key, config)
        end
      end

      def gen_timestamp do
        unquote(config)
        |> Core.put_impl_m(__MODULE__)
        |> Core.save_config()
        |> Core.gen_timestamp()
      end

      def gen_nonce do
        unquote(config)
        |> Core.put_impl_m(__MODULE__)
        |> Core.save_config()
        |> Core.gen_nonce()
      end
    end
  end
end
