defmodule ExHmac do
  @moduledoc false

  alias ExHmac.{Checker, Signer, Noncer, Util}

  alias ExHmac, as: Self

  defmacro __using__(opts) do
    opts = opts |> Util.get_user_opts() |> Macro.escape()

    quote do
      def check_hmac(args, access_key, secret_key) do
        with args <- args |> Util.to_atom_key() |> Keyword.new(),
             opts <- unquote(opts),
             :ok <- Self.check_timestamp(args, opts),
             :ok <- Self.check_nonce(args, opts),
             :ok <- Self.check_signature(args, access_key, secret_key, opts) do
          :ok
        else
          err -> err
        end
      end

      def sign(args, access_key, secret_key) do
        Self.sign(args, access_key, secret_key, unquote(opts))
      end

      def gen_timestamp(precision \\ :second), do: Util.get_curr_ts(precision)
      def gen_nonce(len \\ 6), do: Noncer.gen_nonce(len)
    end
  end

  def check_timestamp(args, opts) do
    with %{timestamp_name: timestamp_name} <- opts,
         {timestamp, _} <- Keyword.pop(args, timestamp_name),
         :ok = result <- Checker.check_timestamp(timestamp, opts) do
      result
    else
      err -> err
    end
  end

  def check_nonce(args, opts) do
    with %{nonce_name: nonce_name} <- opts,
         {nonce, _} <- Keyword.pop(args, nonce_name),
         :ok = result <- Checker.check_nonce(nonce, opts) do
      result
    else
      err -> err
    end
  end

  def check_signature(args, access_key, secret_key, opts) do
    with %{signature_name: signature_name} <- opts,
         {signature, _} <- Keyword.pop(args, signature_name),
         my_signature <- sign(args, access_key, secret_key, opts),
         true <- signature == my_signature do
      :ok
    else
      _ -> :invalid_signature
    end
  end

  def sign(args, access_key, secret_key, opts) do
    args
    |> Signer.make_sign_string(access_key, secret_key, opts)
    |> Signer.do_sign(:sha256)
  end
end
