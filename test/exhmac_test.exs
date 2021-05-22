defmodule ExHmacTest do
  use ExUnit.Case
  doctest ExHmac

  test "say hello" do
    assert ExHmac.hello() == :ExHmac
  end
end
