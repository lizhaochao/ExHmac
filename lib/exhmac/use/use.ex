defmodule ExHmac.Use do
  @moduledoc false

  alias ExHmac.{Config, Util}
  alias ExHmac.Use.Helper

  defmacro __using__(opts) do
    config = opts |> Config.get_config() |> Macro.escape()

    quote do
      def check_hmac(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             config <- Map.put(unquote(config), :impl_m, __MODULE__),
             :ok <- Helper.check_timestamp(args, config),
             :ok <- Helper.check_nonce(args, config),
             :ok <- Helper.check_signature(args, access_key, secret_key, config) do
          :ok
        else
          err -> err
        end
      end

      def sign(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             config <- Map.put(unquote(config), :impl_m, __MODULE__) do
          Helper.sign(args, access_key, secret_key, config)
        end
      end

      def gen_timestamp, do: Helper.gen_timestamp(unquote(config))
      def gen_nonce, do: Helper.gen_nonce(unquote(config))
    end
  end
end
