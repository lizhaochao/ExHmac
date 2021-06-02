defmodule ExHmac.KVRepo do
  @moduledoc false

  alias ExHmac.KVRepo.Server

  ###
  def get(fun), do: GenServer.call(Server, {:get, fun})
  def update(fun), do: GenServer.cast(Server, {:update, fun})

  ###
  def init, do: GenServer.call(Server, :init)
  def get_repo, do: GenServer.call(Server, :get_repo)
end

defmodule ExHmac.KVRepo.Server do
  @moduledoc false

  use GenServer

  ### ### ### ### ### Data Structure Example ### ### ### ### ### ### ### ###
  ###  Repo SnapShoot                                                    ###
  ###  %{                                                                ###
  ###    meta: %{                                                        ###
  ###      count: %{27_042_870 => 0, 27_042_885 => 0, 27_042_900 => 1},  ###
  ###      mins: #MapSet<[27042870, 27042885, 27042900]>,                ###
  ###      shards: %{                                                    ###
  ###        27_042_870 => #MapSet<[]>,                                  ###
  ###        27_042_885 => #MapSet<[]>,                                  ###
  ###        27_042_900 => #MapSet<["A1B2C3"]>                           ###
  ###      }                                                             ###
  ###    },                                                              ###
  ###    nonces: %{"A1B2C3" => 1_622_574_051_220}                        ###
  ###  }                                                                 ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##

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
  def handle_call(:init, _from, _repo) do
    new_repo = @init_repo
    {:reply, new_repo, new_repo}
  end

  @impl true
  def handle_call(:get_repo, _from, repo), do: {:reply, repo, repo}

  @impl true
  def handle_call({:get, fun}, _from, repo) do
    {value, new_repo} = fun.(repo)
    {:reply, value, new_repo}
  end

  ## async
  @impl true
  def handle_cast({:update, fun}, repo) do
    new_repo = fun.(repo)
    {:noreply, new_repo}
  end
end
