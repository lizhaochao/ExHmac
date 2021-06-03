defmodule ExHmac.Application do
  @moduledoc false
  use Application

  alias ExHmac.Config

  def start(_type, _args) do
    with(
      children <- [ExHmac.Noncer.Server, ExHmac.KVRepo.Server],
      new_children <- if(Config.get_disable_noncer(), do: [], else: children),
      opts <- [strategy: :one_for_one, name: ExHmac.Supervisor]
    ) do
      Supervisor.start_link(new_children, opts)
    end
  end
end
