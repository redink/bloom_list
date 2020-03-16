defmodule BloomList.MixProject do
  use Mix.Project

  def project do
    [
      app: :bloom_list,
      version: "1.0.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        paths: ["_build/dev/lib/bloom_list/ebin"],
        flags: [:unmatched_returns, :error_handling, :race_conditions, :no_opaque]
      ],
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bloomex, "~> 1.0"},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: [:dev, :test]},
      {:excoveralls, "~> 0.10", only: [:test]},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "BloomList built on bloomfilter support callback to double check."
  end

  defp package do
    [
      name: "bloom_list",
      maintainers: ["redink"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/redink/bloom_list"}
    ]
  end

  # __end_of_module__
end
