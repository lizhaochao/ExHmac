defmodule ExHmacBench do
  use Benchfella

  alias ExHmac.{Config, Core}
  alias ExHmac.Use.Helper

  @long_string "StringShouldChange-some_stuffStringShouldChange-some_stuffStringShouldChange-some_stuffStringShouldChange-some_stuffStringShouldChange-some_stuff"

  @config Config.get_config([])

  bench "sign/4" do
    Core.sign([name: @long_string], "access_key", "secret_key", @config)
  end

  bench "get_access_key/2" do
    Core.get_access_key([name: @long_string], @config)
  end

  bench "make_arg_names/1" do
    Helper.make_arg_names([
      {:access_key, [], nil},
      {:timestamp, [], nil},
      {:nonce, [], nil},
      {:signature, [], nil}
    ])
  end
end
