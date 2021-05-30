defmodule ExHmac.KVRepo do
  @moduledoc false

  use GenServer

  ### Public Interface
  def start_link(opts) when is_list(opts) do
    with impl_m <- __MODULE__,
         repo_name <- impl_m,
         name_opt <- [name: repo_name] do
      GenServer.start_link(impl_m, :ok, opts ++ name_opt)
    end
  end

  def fetch(key) do
    GenServer.call(__MODULE__, {:fetch, key})
  end

  def get_and_update(key, fun) when is_function(fun) do
    GenServer.cast(__MODULE__, {:get_and_update, key, fun})
  end

  def put(key, value) do
    GenServer.cast(__MODULE__, {:put, key, value})
  end

  def drop(keys) when is_list(keys) do
    GenServer.cast(__MODULE__, {:drop, keys})
  end

  ### Server Callbacks
  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:fetch, key}, _from, repo) do
    value = Map.fetch(repo, key)
    {:reply, value, repo}
  end

  @impl true
  def handle_cast({:get_and_update, key, fun}, repo) do
    {_, repo} = Map.get_and_update(repo, key, fun)
    {:noreply, repo}
  end

  @impl true
  def handle_cast({:put, key, value}, repo) do
    repo = Map.put(repo, key, value)
    {:noreply, repo}
  end

  @impl true
  def handle_cast({:drop, keys}, repo) do
    repo = Map.drop(repo, keys)
    {:noreply, repo}
  end
end
