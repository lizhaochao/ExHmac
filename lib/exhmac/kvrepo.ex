defmodule ExHmac.KVRepo do
  @moduledoc false

  alias ExHmac.KVRepo.Server

  ### Public Interface
  def get_repo, do: GenServer.call(Server, :get_repo)

  def get_and_update_nonce(nonce, curr_ts) do
    GenServer.call(Server, {:get_and_update_nonce, nonce, curr_ts})
  end

  def fetch(key), do: GenServer.call(Server, {:fetch, key})

  def get_in(path), do: GenServer.call(Server, {:get_in, path})

  def get_and_update(key, fun), do: GenServer.call(Server, {:get_and_update, key, fun})

  def put(key, value), do: GenServer.cast(Server, {:put, key, value})

  def put_in(path, value), do: GenServer.cast(Server, {:put_in, path, value})

  def drop(keys), do: GenServer.cast(Server, {:drop, keys})
end

defmodule ExHmac.KVRepo.Server do
  @moduledoc false

  use GenServer

  ### ### ### ### ### Data Structure Example ### ### ### ### ###
  ###    %{                                                  ###
  ###      :nonces => %{                                     ###
  ###        "bbU9Z1" => 1_622_459_320,                      ###
  ###        "ccu0w7" => 1_622_459_310                       ###
  ###      },                                                ###
  ###      meta: %{                                          ###
  ###        :count => %{                                    ###
  ###          27_040_989 => 2,                              ###
  ###          27_040_988 => 3                               ###
  ###        },                                              ###
  ###        :shards => %{                                   ###
  ###          27_040_989 => ["22U9Z1", "11k9l2"],           ###
  ###          27_040_988 => ["ccu0w7", "bbU9Z1", "aak9l2"]  ###
  ###        },                                              ###
  ###        :mins => [27_040_988, 27_040_989]               ###
  ###      }                                                 ###
  ###    }                                                   ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  @init_repo %{nonces: %{}, meta: %{count: %{}, shards: %{}, mins: MapSet.new()}}

  def start_link(opts) when is_list(opts) do
    with(
      impl_m <- __MODULE__,
      repo_name <- impl_m,
      name_opt <- [name: repo_name]
    ) do
      GenServer.start_link(impl_m, :ok, opts ++ name_opt)
    end
  end

  @impl true
  def init(:ok), do: {:ok, @init_repo}

  ## sync
  @impl true
  def handle_call(:get_repo, _from, repo), do: {:reply, repo, repo}

  @impl true
  def handle_call({:get_and_update_nonce, nonce, curr_ts}, _from, repo) do
    with(
      arrived_at <- get_in(repo, [:nonces, nonce]),
      new_repo <- put_in(repo, [:nonces, nonce], curr_ts)
    ) do
      {:reply, arrived_at, new_repo}
    end
  end

  @impl true
  def handle_call({:fetch, key}, _from, repo) do
    value = Map.fetch(repo, key)
    {:reply, value, repo}
  end

  @impl true
  def handle_call({:get_in, path}, _from, repo) do
    value = get_in(repo, path)
    {:reply, value, repo}
  end

  @impl true
  def handle_call({:get_and_update, key, fun}, _from, repo) do
    {_, new_repo} = result = Map.get_and_update(repo, key, fun)
    {:reply, result, new_repo}
  end

  ## async
  @impl true
  def handle_cast({:put, key, value}, repo) do
    new_repo = Map.put(repo, key, value)
    {:noreply, new_repo}
  end

  @impl true
  def handle_cast({:put_in, path, value}, repo) do
    new_repo = put_in(repo, path, value)
    {:noreply, new_repo}
  end

  @impl true
  def handle_cast({:drop, keys}, repo) do
    new_repo = Map.drop(repo, keys)
    {:noreply, new_repo}
  end
end
