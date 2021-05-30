defmodule ExHmac.TestHelper do
  @moduledoc false

  def get_error_code, do: -1

  def get_test_access_key, do: "test_key_ljy"
  def get_test_secret_key, do: "test_secret_ljy"

  def serialize({:ok, json_string}), do: json_string
  def serialize(params), do: params |> Map.new() |> Poison.encode() |> serialize()

  def deserialize({:ok, map}), do: map
  def deserialize(json_string), do: json_string |> Poison.decode() |> deserialize()

  def to_json_string(term), do: Poison.encode(term)
end
