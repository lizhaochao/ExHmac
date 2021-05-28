defmodule ExHmac.Util do
  @moduledoc false

  alias ExHmac.{Const, Error}

  @default_access_key_name Const.default_access_key_name()
  @default_secret_key_name Const.default_secret_key_name()
  @default_signature_name Const.default_signature_name()
  @default_timestamp_name Const.default_timestamp_name()
  @default_nonce_name Const.default_nonce_name()
  @default_timestamp_offset_seconds Const.default_timestamp_offset_seconds()
  @default_nonce_ttl Const.default_nonce_ttl()

  def contain_hmac?(hash_alg) when is_atom(hash_alg) do
    hash_alg
    |> to_string()
    |> String.downcase()
    |> String.slice(0, 4)
    |> Kernel.==("hmac")
  end

  def contain_hmac?(_other), do: raise(Error, "hash_alg should be atom")

  def get_curr_ts(prec \\ :second)
  def get_curr_ts(:millisecond = prec), do: DateTime.utc_now() |> DateTime.to_unix(prec)
  def get_curr_ts(_), do: DateTime.utc_now() |> DateTime.to_unix(:second)

  def get_user_opts(opts) when is_list(opts) do
    %{
      timestamp_offset_seconds:
        Keyword.get(opts, :timestamp_offset_seconds, @default_timestamp_offset_seconds),
      nonce_ttl: Keyword.get(opts, :nonce_ttl, @default_nonce_ttl),
      access_key_name: Keyword.get(opts, :access_key_name, @default_access_key_name),
      secret_key_name: Keyword.get(opts, :secret_key_name, @default_secret_key_name),
      signature_name: Keyword.get(opts, :secret_key_name, @default_signature_name),
      timestamp_name: Keyword.get(opts, :timestamp_name, @default_timestamp_name),
      nonce_name: Keyword.get(opts, :nonce_name, @default_nonce_name),
      hash_alg: Keyword.get(opts, :hash_alg, :sha256),
      precision: Keyword.get(opts, :precision, :second),
      warn: Keyword.get(opts, :warn, true)
    }
  end

  ###
  def to_atom_key(%_{} = map), do: map |> struct_to_map() |> to_atom_key()
  def to_atom_key(%{} = map), do: traverse_map(map)
  def to_atom_key(other), do: other

  defp traverse_map(%{} = map) when map_size(map) == 0, do: map
  defp traverse_map(%{} = map), do: map |> Enum.into([]) |> do_traverse_map([])

  defp do_traverse_map([], new_map), do: Map.new(new_map)

  defp do_traverse_map([{k, v} | rest], new_map) when is_list(v) do
    new_v = traverse_list(v, [])
    do_traverse_map(rest, [{string_to_atom(k), new_v} | new_map])
  end

  defp do_traverse_map([{k, %{} = v} | rest], new_map) do
    new_v = traverse_map(v)
    do_traverse_map(rest, [{string_to_atom(k), new_v} | new_map])
  end

  defp do_traverse_map([{k, v} | rest], new_map) do
    do_traverse_map(rest, [{string_to_atom(k), v} | new_map])
  end

  defp traverse_list([], new_list), do: Enum.reverse(new_list)

  defp traverse_list([%{} = m | rest], new_list) do
    new_m = traverse_map(m)
    traverse_list(rest, [new_m | new_list])
  end

  defp traverse_list([term | rest], new_list), do: traverse_list(rest, [term | new_list])

  defp string_to_atom(term) when is_bitstring(term), do: String.to_atom(term)
  defp string_to_atom(term) when is_atom(term), do: term

  defp struct_to_map(%_{} = struct), do: Map.drop(struct, [:__meta__, :__struct__])
  defp struct_to_map(other), do: other
end
