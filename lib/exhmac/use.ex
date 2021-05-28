defmodule ExHmac.Use do
  @moduledoc false

  alias ExHmac.{Checker, Config, Signer, Noncer, Util}
  alias ExHmac.Use, as: Self

  defmacro __using__(opts) do
    opts = opts |> Config.get_config() |> Macro.escape()

    quote do
      def check_hmac(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             opts <- unquote(opts),
             :ok <- Self.check_timestamp(args, opts),
             :ok <- Self.check_nonce(args, opts),
             :ok <- Self.check_signature(args, access_key, secret_key, opts) do
          :ok
        else
          err -> err
        end
      end

      def sign(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             opts <- unquote(opts) do
          Self.sign(args, access_key, secret_key, opts)
        end
      end

      def gen_timestamp(precision \\ nil), do: Self.gen_timestamp(precision, unquote(opts))
      def gen_nonce(len \\ nil), do: Self.gen_nonce(len, unquote(opts))
    end
  end

  ###
  def check_timestamp(args, opts) do
    with %{timestamp_name: timestamp_name} <- opts,
         {:ok, timestamp} <- Keyword.fetch(args, timestamp_name) do
      Checker.check_timestamp(timestamp, opts)
    else
      :error -> :not_found_timestamp
      err -> err
    end
  end

  def check_nonce(args, opts) do
    with %{nonce_name: nonce_name} <- opts,
         {:ok, nonce} <- Keyword.fetch(args, nonce_name) do
      Checker.check_nonce(nonce, opts)
    else
      :error -> :not_found_nonce
      err -> err
    end
  end

  def check_signature(args, access_key, secret_key, opts) do
    with %{signature_name: signature_name} <- opts,
         {signature, args} when not is_nil(signature) <- Keyword.pop(args, signature_name),
         my_signature <- sign(args, access_key, secret_key, opts),
         true <- signature == my_signature do
      :ok
    else
      _ -> :signature_error
    end
  end

  ###
  def sign(args, access_key, secret_key, opts) do
    with %{hash_alg: hash_alg} <- opts,
         sign_string <- Signer.make_sign_string(args, access_key, secret_key, opts) do
      do_sign(hash_alg, sign_string, access_key)
    end
  end

  def do_sign(hash_alg, sign_string, access_key) do
    with true <- Util.contain_hmac?(hash_alg),
         hash_alg <- Util.prune_hash_alg(hash_alg) do
      Signer.do_sign(sign_string, hash_alg, access_key)
    else
      false -> Signer.do_sign(sign_string, hash_alg)
    end
  end

  ###
  def gen_timestamp(prec, opts) do
    with %{precision: precision} <- opts,
         precision <- prec || precision do
      Util.get_curr_ts(precision)
    end
  end

  ###
  def gen_nonce(len, opts) do
    with %{nonce_len: nonce_len} <- opts,
         nonce_len <- len || nonce_len do
      Noncer.gen_nonce(nonce_len)
    end
  end
end
