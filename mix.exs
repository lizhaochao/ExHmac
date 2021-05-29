defmodule ExHmac.MixProject do
  use Mix.Project

  @description "HMAC Authentication"

  @gitee_repo_url "https://gitee.com/lizhaochao/exhmac"
  @github_repo_url "https://github.com/lizhaochao/exhmac"

  @version "0.1.0"

  def project do
    [
      app: :ExHmac,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Test
      test_pattern: "*_test.exs",

      # Hex
      package: package(),
      description: @description,

      # Docs
      name: "ExHmac",
      docs: [main: "ExHmac"]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:poison, "> 0.0.0"},
      {:decorator, "> 0.0.0"},
      # Dev and test dependencies
      {:excoveralls, "> 0.0.0", only: :test},
      {:propcheck, "> 0.0.0", only: :test},
      {:credo, "> 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "> 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "> 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "exhmac",
      maintainers: ["lizhaochao"],
      licenses: ["MIT"],
      links: %{"Gitee" => @gitee_repo_url, "GitHub" => @github_repo_url}
    ]
  end

  defp aliases, do: [test: ["format", "test"]]
end
