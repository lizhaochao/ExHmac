defmodule ExHmac.Parser do
  @moduledoc false

  alias ExHmac.Error

  def parser(call), do: do_parse(call)
  def do_parse({_f, _, a}) when is_nil(a) or a == [], do: raise(Error, "args is empty.")
  def do_parse({:when, _, [{f, _, [_ | _] = a}, guard]}), do: {f, a, guard}
  def do_parse({f, _, [_ | _] = a}), do: {f, a, true}
end
