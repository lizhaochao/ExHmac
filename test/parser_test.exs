defmodule ParserTest do
  use ExUnit.Case

  alias ExHmac.Parser

  describe "do_parse/1" do
    test "args is empty" do
      expr = quote do: sign_in()

      assert_raise ExHmac.Error, fn ->
        Parser.do_parse(expr)
      end
    end

    test "only args" do
      expr = quote do: sign_in(username)
      {f, [{a_name, _, _}], true} = Parser.do_parse(expr)
      assert :sign_in == f
      assert :username == a_name

      ###
      expr = quote do: sign_in(username, passwd)
      {f, [{a_name1, _, _}, {a_name2, _, _}], true} = Parser.do_parse(expr)
      assert :sign_in == f
      assert :username == a_name1
      assert :passwd == a_name2
    end

    test "args & guard" do
      expr = quote do: sign_in(a) when is_integer(a)
      {:sign_in, [{:a, _, _}], {:is_integer, _, _}} = Parser.do_parse(expr)

      expr = quote do: sign_in(a, b) when is_integer(a) and is_nil(b)
      {:sign_in, [{:a, _, _} | _], {:and, _, _}} = Parser.do_parse(expr)

      expr = quote do: sign_in(a, b, c) when is_integer(a) or (is_integer(b) and is_float(c))
      {:sign_in, [{:a, _, _} | _], {:or, _, _}} = Parser.do_parse(expr)

      expr = quote do: sign_in(a, b, c) when is_integer(a) or is_integer(b) or is_float(c)
      {:sign_in, [{:a, _, _} | _], {:or, _, _}} = Parser.do_parse(expr)

      expr = quote do: sign_in(a, b, c) when is_integer(a) and is_integer(b) and is_float(c)
      {:sign_in, [{:a, _, _} | _], {:and, _, _}} = Parser.do_parse(expr)
    end
  end
end
