defmodule ExHmac.Util do
  @moduledoc false

  require Logger

  alias ExHmac.{Config, Error}

  @support_hash_algs Config.support_hash_algs()
  @hmac_hash_alg_prefix Config.hmac_hash_alg_prefix()

  def contain_hmac?(hash_alg) when is_atom(hash_alg) do
    hash_alg
    |> to_string()
    |> String.downcase()
    |> String.slice(0, String.length(@hmac_hash_alg_prefix))
    |> Kernel.==(@hmac_hash_alg_prefix)
  end

  def contain_hmac?(_other), do: raise(Error, "hash_alg should be atom")

  def prune_hash_alg(hash_alg) do
    hash_alg
    |> to_string()
    |> String.downcase()
    |> String.replace(@hmac_hash_alg_prefix, "")
    |> String.to_atom()
    |> case do
      pruned_hash_alg when pruned_hash_alg in @support_hash_algs -> pruned_hash_alg
      _ -> raise(Error, "not support hash alg: #{inspect(hash_alg)}")
    end
  end

  def get_curr_ts(prec \\ :second)
  def get_curr_ts(:millisecond = prec), do: DateTime.utc_now() |> DateTime.to_unix(prec)
  def get_curr_ts(_second), do: DateTime.utc_now() |> DateTime.to_unix(:second)

  def to_keyword(term) when is_list(term), do: term
  def to_keyword(term) when is_map(term), do: Enum.into(term, [])

  def to_minute(nil = ts, _precision), do: ts

  def to_minute(ts, precision) do
    case precision do
      :millisecond -> ts / 1000 / 60
      _second -> ts / 60
    end
    |> trunc()
  end

  def log(level, [type | _] = content, log_color) do
    if Application.get_env(:exhmac, :log, true) do
      Logger.log(level, fn -> content end, ansi_color: log_color.(level, type))
    end
  end

  ###
  def to_atom_key(map), do: AtomicMap.convert(map, %{safe: false, underscore: false})
end
