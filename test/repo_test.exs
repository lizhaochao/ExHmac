defmodule RepoTest do
  ### ### ### ### ### !!! NOTICE !!! ### ### ### ### ###
  ###       If Failed, Run The Following Command:    ###
  ###                mix test --seed 0               ###
  ### ### ### ### ### ### ### ### ### ### ### ### ### ##

  use ExUnit.Case

  alias ExHmac.Repo

  test "get -> update -> get" do
    with(
      key <- :ljy,
      value <- :lijiayou,
      get_fun <- fn repo ->
        value = Map.get(repo, key)
        {value, repo}
      end,
      update_fun <- fn repo -> Map.put(repo, key, value) end
    ) do
      assert nil == Repo.get(get_fun)
      assert :ok == Repo.update(update_fun)
      assert :lijiayou == Repo.get(get_fun)
    end
  end
end
