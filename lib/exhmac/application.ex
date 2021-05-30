defmodule ExHmac.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      ExHmac.KVRepo
    ]

    opts = [strategy: :one_for_one, name: ExHmac.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
