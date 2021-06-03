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

defmodule ExHmac.Use.Decorator do
  @moduledoc false

  alias ExHmac.{Config, Checker, Util}
  alias ExHmac.Use.Helper
  alias ExHmac.Use.Decorator, as: Self

  defmacro __using__(opts) do
    quote do
      def check_hmac(body, %Decorator.Decorate.Context{} = ctx) do
        config = unquote(opts) |> Config.get_config() |> Map.put(:impl_m, __MODULE__)
        Self.pre_check(config)

        with config_expr <- Macro.escape(config),
             %{args: args_expr} <- ctx do
          args_expr
          |> Self.make_arg_names()
          |> Self.check_hmac(args_expr, body, config_expr)
        end
      end
    end
  end

  def check_hmac(arg_names, args_expr, body, config_expr) do
    quote do
      with exec_body <- fn -> unquote(body) end,
           arg_values <- unquote(args_expr),
           args <- Self.make_args(unquote(arg_names), arg_values) do
        Self.do_check_hmac(args, exec_body, unquote(config_expr))
      end
    end
  end

  def pre_check(config) do
    %{impl_m: impl_m, get_secret_key_function_name: get_secret_key_function_name} = config
    Checker.require_function!(impl_m, get_secret_key_function_name, 1)
  end

  ###
  def do_check_hmac(args, exec_body, config)
      when is_list(args) and is_function(exec_body) do
    with access_key when is_bitstring(access_key) <- get_access_key(args, config),
         secret_key when is_bitstring(secret_key) <- get_secret_key(access_key, config),
         resp <- do_check_hmac(args, access_key, secret_key, exec_body, config),
         resp <- fmt_resp(resp, config) do
      Helper.make_resp(resp, config, access_key, secret_key)
    else
      err_without_hmac -> err_without_hmac |> fmt_resp(config) |> Helper.make_resp(config)
    end
  end

  def do_check_hmac(args, access_key, secret_key, exec_body, config) do
    with :ok <- Helper.check_timestamp(args, config),
         :ok <- Helper.check_nonce(args, config),
         :ok <- Helper.check_signature(args, access_key, secret_key, config) do
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
  def get_access_key(args, config) do
    %{access_key_name: access_key_name} = config

    args
    |> Keyword.fetch(access_key_name)
    |> case do
      :error -> :not_found_access_key
      {:ok, access_key} when is_bitstring(access_key) and access_key != "" -> access_key
      _access_key -> :access_key_error
    end
  end

  def get_secret_key(access_key, config) do
    %{impl_m: impl_m, get_secret_key_function_name: get_secret_key_function_name} = config

    impl_m
    |> apply(get_secret_key_function_name, [access_key])
    |> case do
      secret_key when is_bitstring(secret_key) -> secret_key
      secret_key when is_nil(secret_key) or secret_key == "" -> :access_key_error
      err when is_atom(err) -> err
      _ -> :get_secret_key_error
    end
  end

  ###
  def fmt_resp(resp, config) do
    with(
      %{impl_m: impl_m} <- config,
      {f, a} <- __ENV__.function,
      true <- function_exported?(impl_m, f, a - 1),
      resp <- apply(impl_m, f, [resp])
    ) do
      {:fmt, resp}
    else
      false -> {:default, resp}
    end
  end
end

defmodule ExHmac.Use.Helper do
  @moduledoc false

  alias ExHmac.{Checker, Signer, Noncer, Util}

  def check_timestamp(args, config) do
    with %{timestamp_name: timestamp_name} <- config,
         {:ok, timestamp} <- Keyword.fetch(args, timestamp_name) do
      Checker.check_timestamp(timestamp, config)
    else
      :error -> :not_found_timestamp
      err -> err
    end
  end

  def check_nonce(args, config) do
    with %{nonce_name: nonce_name} <- config,
         {:ok, nonce} <- Keyword.fetch(args, nonce_name) do
      Checker.check_nonce(nonce)
    else
      :error -> :not_found_nonce
      err -> err
    end
  end

  def check_signature(args, access_key, secret_key, config) do
    with %{signature_name: signature_name} <- config,
         {signature, args} when not is_nil(signature) <- Keyword.pop(args, signature_name),
         my_signature <- sign(args, access_key, secret_key, config),
         true <- signature == my_signature do
      :ok
    else
      _ -> :signature_error
    end
  end

  ###
  def sign(args, access_key, secret_key, config) do
    with %{hash_alg: hash_alg} <- config,
         sign_string <- Signer.make_sign_string(args, access_key, secret_key, config) do
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
  def gen_timestamp(prec, config) do
    with precision <- prec || Map.get(config, :precision) do
      Util.get_curr_ts(precision)
    end
  end

  ###
  def gen_nonce(len, config) do
    with nonce_len <- len || Map.get(config, :nonce_len) do
      Noncer.gen_nonce(nonce_len)
    end
  end

  ###
  def make_resp({:default, resp}, config) do
    resp_data_name = get_resp_data_name(resp, config)
    Keyword.put([], resp_data_name, resp)
  end

  def make_resp({:fmt, resp}, _config) do
    resp
    |> Checker.keyword_or_map!("resp")
    |> Util.to_keyword()
  end

  def make_resp({:default, _} = default_resp, config, access_key, secret_key) do
    default_resp
    |> make_resp(config)
    |> append_hmac(config, access_key, secret_key)
  end

  def make_resp({:fmt, resp}, config, access_key, secret_key) do
    resp
    |> Checker.keyword_or_map!("resp")
    |> Util.to_keyword()
    |> append_hmac(config, access_key, secret_key)
  end

  #
  def append_hmac(resp, config, access_key, secret_key) do
    with args <- make_resp_args(resp, config),
         signature <- sign(args, access_key, secret_key, config),
         args <- put_signature(args, signature, config) do
      args
    end
  end

  def make_resp_args(resp, config) do
    with %{
           timestamp_name: timestamp_name,
           nonce_name: nonce_name
         } <- config do
      []
      |> Keyword.put(timestamp_name, gen_timestamp(nil, config))
      |> Keyword.put(nonce_name, gen_nonce(nil, config))
      |> Keyword.merge(resp)
    end
  end

  def put_signature(args, signature, config) do
    with %{signature_name: signature_name} <- config do
      Keyword.put(args, signature_name, signature)
    end
  end

  def get_resp_data_name(resp, config) do
    %{
      resp_succ_data_name: resp_succ_data_name,
      resp_fail_data_name: resp_fail_data_name
    } = config

    case resp do
      resp when is_atom(resp) -> resp_fail_data_name
      _resp -> resp_succ_data_name
    end
  end
end
