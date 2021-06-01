defmodule ExHmac.KVRepo do
  @moduledoc false

  use GenServer

  ### ### ### ### ### Data Structure Example ### ### ### ### ###
  ###    %{                                                  ###
  ###      :nonces => %{                                     ###
  ###        "bbU9Z1" => 1_622_459_320,                      ###
  ###        "ccu0w7" => 1_622_459_310                       ###
  ###      },                                                ###
  ###      :mins => [27_040_988, 27_040_989],                ###
  ###      :count => %{                                      ###
  ###        27_040_989 => 2,                                ###
  ###        27_040_988 => 3                                 ###
  ###      },                                                ###
  ###      :shards => %{                                     ###
  ###        27_040_989 => ["22U9Z1", "11k9l2"],             ###
  ###        27_040_988 => ["ccu0w7", "bbU9Z1", "aak9l2"]    ###
  ###      }                                                 ###
  ###    }                                                   ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  @init_repo %{nonces: %{}, count: %{}, shards: %{}, mins: MapSet.new()}

  ### Public Interface
  def start_link(opts) when is_list(opts) do
    with(
      impl_m <- __MODULE__,
      repo_name <- impl_m,
      name_opt <- [name: repo_name]
    ) do
      GenServer.start_link(impl_m, :ok, opts ++ name_opt)
    end
  end

  def get_repo, do: GenServer.call(__MODULE__, :get_repo)

  def fetch(key), do: GenServer.call(__MODULE__, {:fetch, key})

  def get_and_update(key, fun), do: GenServer.call(__MODULE__, {:get_and_update, key, fun})

  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})

  def drop(keys), do: GenServer.cast(__MODULE__, {:drop, keys})

  ### Server Callbacks
  @impl true
  def init(:ok), do: {:ok, @init_repo}

  @impl true
  def handle_call(:get_repo, _from, repo), do: {:reply, repo, repo}

  @impl true
  def handle_call({:fetch, key}, _from, repo) do
    value = Map.fetch(repo, key)
    {:reply, value, repo}
  end

  @impl true
  def handle_call({:get_and_update, key, fun}, _from, repo) do
    {_, new_repo} = result = Map.get_and_update(repo, key, fun)
    {:reply, result, new_repo}
  end

  @impl true
  def handle_cast({:put, key, value}, repo) do
    new_repo = Map.put(repo, key, value)
    {:noreply, new_repo}
  end

  @impl true
  def handle_cast({:drop, keys}, repo) do
    new_repo = Map.drop(repo, keys)
    {:noreply, new_repo}
  end
end
