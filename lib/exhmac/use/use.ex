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
             config <- unquote(config) do
          Helper.sign(args, access_key, secret_key, config)
        end
      end

      def gen_timestamp(precision \\ nil), do: Helper.gen_timestamp(precision, unquote(config))
      def gen_nonce(len \\ nil), do: Helper.gen_nonce(len, unquote(config))
    end
  end
end
