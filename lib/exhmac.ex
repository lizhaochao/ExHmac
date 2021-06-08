defmodule ExHmac do
  @moduledoc ~S"""
  HMAC Authentication
  ## Example
  This Example Project is the basis for ExHmac, help you use well.

  Download via [Gitee](https://gitee.com/lizhaochao/exhmac_example) or [Github](https://github.com/lizhaochao/exhmac_example).

  Once downloaded, Two Things Todo:

  ```bash
  mix deps.get
  mix test
  ```
  ```bash
  # confirm gc configs which are expected, run following commands.
  # use test.exs to run
  MIX_ENV=test iex -S mix
  # use dev.exs to run
  iex -S mix
  ```
  ## Usage
  ### Quick Start
  Here’s a commented example.
  ```elixir
  # Use ExHmac like this in Your Project.
  iex> defmodule YourProject do
  ...>   # inject hmac functions to current scope via use ExHmac.
  ...>   use ExHmac, precision: :millisecond
  ...>
  ...>   @access_key "exhmac_key"
  ...>   @secret_key "exhmac_secret"
  ...>
  ...>   # use gen_timestamp/0, gen_nonce/0 to make params.
  ...>   def make_params(name) do
  ...>     [name: name, timestamp: gen_timestamp(), nonce: gen_nonce()]
  ...>   end
  ...>
  ...>   # make signature with access_key & secret_key using sign/3.
  ...>   def make_signature(params) do
  ...>     sign(params, @access_key, @secret_key)
  ...>   end
  ...>
  ...>   # use sign/3 & check_hmac/3 to make resp with hmac
  ...>   def start_request(name) do
  ...>     # simulate request, prepare params
  ...>     params = make_params(name)
  ...>     signature = make_signature(params)
  ...>     _req_params = [signature: signature] ++ params
  ...>
  ...>     # simulate response data
  ...>     resp_params = [result: 0, timestamp: gen_timestamp(), nonce: gen_nonce()]
  ...>     signature = sign(resp_params, @access_key, @secret_key)
  ...>     resp_params = [signature: signature] ++ resp_params
  ...>     check_hmac(resp_params, @access_key, @secret_key)
  ...>   end
  ...> end
  ...>
  iex> # start request & get check response result
  ...> YourProject.start_request("ljy")
  :ok
  ```
  ### Check via decorator (Recommended)
  `Doc is cheap`, ` Show you the Code.` [Download Example](#example).

  ### Check via defhmac macro (Recommended)
  `Doc is cheap`, ` Show you the Code.` [Download Example](#example)

  ## Customize Hmac
  ### Support Hash Algs
  - `:sha` & `:hmac_sha`
  - `:sha512` & `:hmac_sha512`
  - `:sha384` & `:hmac_sha384`
  - `:sha256` & `:hmac_sha256`
  - `:sha224` & `:hmac_sha224`
  - `:sha3_512` & `:hmac_sha3_512`
  - `:sha3_384` & `:hmac_sha3_384`
  - `:sha3_256` & `:hmac_sha3_256`
  - `:sha3_224` & `:hmac_sha3_224`
  - `:blake2b` & `:hmac_blake2b`
  - `:blake2s` & `:hmac_blake2s`
  - `:md5` & `:hmac_md5`

  Implements:
  ```elixir
  # :sha256
  :crypto.hash(:sha256, "sign string")
  # :hmac_sha256
  :crypto.mac(:hmac, :sha256, "access_key", "sign string")
  ```

  ### Hooks
  - `pre_hook/1`, before check hmac, give you origin args with keyword.
  - `post_hook/1`, after check hmac, this output is final.

  These hokks only effect decorator & defhmac.

  ### Callbacks
  - `get_access_key/1`, get/evaluate access key from input args.
  - `get_secret_key/1`, required, you must provide secret.
  - `check_nonce/4`, If you want to use Redis getset command to check nonce, then implements it.
  - `make_sign_string/3`, change sign string rule.
  - `encode_hash_result/1`, defaults to encode hex string.
  - `fmt_resp/1`, format resp to your own format, like: `%{result: 0, error_msg: "some error"}`.
  - `gc_log_callback/1`, defaults to in-memory cache with gc, collect count up to max will invoke it.

  more detail, please [Download Example](#example).

  ### Available Configs
  as ExHmac opts
  ```elixir
  use ExHmac,
    # once in-memory cache crash, will lose 2 following configs.
    # you should set them again in config.exs.
    precision: :millisecond,
    nonce_freezing_secs: 60,
    # normal configs
    hash_alg: :hmac_sha512,
    warn: false,
    nonce_len: 20,
    timestamp_offset_secs: 900
  ```
  the following configs in config.exs
  ```elixir
  # set them again for exactly gc running.
  config :exhmac, :precision, :millisecond
  config :exhmac, :nonce_freezing_secs, 60
  # normal configs
  config :exhmac, :disable_noncer, false # disable local in-memory cache
  config :exhmac, :gc_interval_milli, 20_000
  config :exhmac, :gc_warn_count, 10
  config :exhmac, :gc_log_callback, &MyHmac.gc_log/1
  ```
  `NOTICE`: `precision` & `nonce_freezing_secs` set 2 places, once you don't want to use default values.
  """

  defmacro __using__(opts) do
    quote do
      use Decorator.Define, check_hmac: 0
      use ExHmac.Use.Decorator, unquote(opts)
      use ExHmac.Use, unquote(opts)
    end
  end
end

defmodule ExHmac.Defhmac do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use ExHmac.Use.Defhmac, unquote(opts)
    end
  end
end
