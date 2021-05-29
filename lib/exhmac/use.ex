defmodule ExHmac.Use do
  @moduledoc false

  alias ExHmac.{Config, Util}
  alias ExHmac.Use.Helper

  defmacro __using__(opts) do
    opts = opts |> Config.get_config() |> Macro.escape()

    quote do
      def check_hmac(args, access_key, secret_key)
          when (is_list(args) or is_map(args)) and is_bitstring(access_key) and
                 is_bitstring(secret_key) do
        with args <- args |> Util.to_atom_key() |> Util.to_keyword(),
             opts <- unquote(opts),
             :ok <- Helper.check_timestamp(args, opts),
             :ok <- Helper.check_nonce(args, opts),
             :ok <- Helper.check_signature(args, access_key, secret_key, opts) do
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
          Helper.sign(args, access_key, secret_key, opts)
        end
      end

      def gen_timestamp(precision \\ nil), do: Helper.gen_timestamp(precision, unquote(opts))
      def gen_nonce(len \\ nil), do: Helper.gen_nonce(len, unquote(opts))
    end
  end
end

defmodule ExHmac.Use.Decorator do
  @moduledoc false

  alias ExHmac.Config
  alias ExHmac.Use.Helper
  alias ExHmac.Use.Decorator, as: Self

  defmacro __using__(opts) do
    quote do
      def check_hmac(body, %Decorator.Decorate.Context{} = ctx) do
        with opts <- unquote(opts) |> Config.get_config() |> Macro.escape(),
             %{args: args_expr} <- ctx,
             arg_names <- Self.make_arg_names(args_expr),
             impl_m <- __MODULE__ do
          Self.check_hmac(arg_names, args_expr, body, opts, impl_m)
        end
      end
    end
  end

  def check_hmac(arg_names, args_expr, body, opts, impl_m) do
    quote do
      with exec_body <- fn -> unquote(body) end,
           arg_values <- unquote(args_expr),
           args <- Self.make_args(unquote(arg_names), arg_values) do
        Self.do_check_hmac(args, exec_body, unquote(opts), unquote(impl_m))
      end
    end
  end

  ###
  def do_check_hmac(args, exec_body, opts, impl_m)
      when is_list(args) and is_function(exec_body) do
    with access_key when is_bitstring(access_key) <- get_access_key(args, opts),
         secret_key when is_bitstring(secret_key) <- get_secret_key(access_key, impl_m),
         resp <- do_check_hmac(args, access_key, secret_key, opts, exec_body) do
      Helper.make_resp(resp, opts, access_key, secret_key)
    else
      err_without_hmac -> Helper.make_resp(err_without_hmac, opts)
    end
  end

  def do_check_hmac(args, access_key, secret_key, opts, exec_body) do
    with :ok <- Helper.check_timestamp(args, opts),
         :ok <- Helper.check_nonce(args, opts),
         :ok <- Helper.check_signature(args, access_key, secret_key, opts) do
      exec_body.()
    else
      err -> err
    end
  end

  def make_arg_names(args_expr) do
    Enum.map(args_expr, fn {name, _, _} ->
      name
      |> to_string()
      |> case do
        "_" <> _rest = str_name -> String.slice(str_name, 1, String.length(str_name) - 1)
        str_name -> str_name
      end
      |> String.to_atom()
    end)
  end

  def make_args(arg_names, arg_values), do: do_make_args(arg_names, arg_values, [])

  def do_make_args([], [], args), do: args

  def do_make_args([name | rest_names], [value | rest_values], args) do
    do_make_args(rest_names, rest_values, [{name, value} | args])
  end

  ###
  def get_access_key(args, opts) do
    %{access_key_name: access_key_name} = opts

    args
    |> Keyword.fetch(access_key_name)
    |> case do
      :error -> :not_found_access_key
      {:ok, access_key} when is_bitstring(access_key) and access_key != "" -> access_key
      _access_key -> :access_key_error
    end
  end

  # TODO: exported? then raise error
  def get_secret_key(access_key, impl_m) do
    impl_m
    |> apply(:get_secret_key, [access_key])
    |> case do
      secret_key when is_bitstring(secret_key) -> secret_key
      secret_key when is_nil(secret_key) or secret_key == "" -> :access_key_error
      err when is_atom(err) -> err
      _ -> :get_secret_key_error
    end
  end
end

defmodule ExHmac.Use.Helper do
  @moduledoc false

  alias ExHmac.{Checker, Signer, Noncer, Util}

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
    with precision <- prec || Map.get(opts, :precision) do
      Util.get_curr_ts(precision)
    end
  end

  ###
  def gen_nonce(len, opts) do
    with nonce_len <- len || Map.get(opts, :nonce_len) do
      Noncer.gen_nonce(nonce_len)
    end
  end

  ###
  # TODO: support custom impl
  def make_resp(resp, opts) do
    %{resp_fail_data_name: resp_fail_data_name} = opts
    Keyword.put([], resp_fail_data_name, resp)
  end

  def make_resp(resp, opts, access_key, secret_key) do
    with args <- make_resp_args(resp, opts),
         signature <- sign(args, access_key, secret_key, opts),
         args <- put_signature(args, signature, opts) do
      args
    end
  end

  def make_resp_args(resp, opts) do
    with %{
           timestamp_name: timestamp_name,
           nonce_name: nonce_name
         } <- opts,
         resp_data_name <- get_resp_data_name(resp, opts) do
      []
      |> Keyword.put(resp_data_name, resp)
      |> Keyword.put(timestamp_name, gen_timestamp(nil, opts))
      |> Keyword.put(nonce_name, gen_nonce(nil, opts))
    end
  end

  def get_resp_data_name(resp, opts) do
    %{
      resp_succ_data_name: resp_succ_data_name,
      resp_fail_data_name: resp_fail_data_name
    } = opts

    case resp do
      resp when is_atom(resp) -> resp_fail_data_name
      _resp -> resp_succ_data_name
    end
  end

  def put_signature(args, signature, opts) do
    with %{signature_name: signature_name} <- opts do
      Keyword.put(args, signature_name, signature)
    end
  end
end
