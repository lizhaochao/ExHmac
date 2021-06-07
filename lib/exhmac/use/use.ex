defmodule ExHmac.Use do
  @moduledoc false

  alias ExHmac.{Config, Util}
  alias ExHmac.Core
  alias ExHmac.Use.Helper

  defmacro __using__(opts) do
    config = opts |> Config.get_config() |> Macro.escape()

    quote do
      def check_hmac(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             config <- Helper.pre_config(unquote(config), __MODULE__),
             :ok <- Core.do_check_hmac(args, access_key, secret_key, config) do
          :ok
        else
          err -> err
        end
      end

      def sign(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             config <- Helper.pre_config(unquote(config), __MODULE__) do
          Core.sign(args, access_key, secret_key, config)
        end
      end

      def gen_timestamp,
        do: unquote(config) |> Helper.pre_config(__MODULE__) |> Core.gen_timestamp()

      def gen_nonce,
        do: unquote(config) |> Helper.pre_config(__MODULE__) |> Core.gen_nonce()
    end
  end
end
