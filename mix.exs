defmodule RyugraphEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :ryugraph_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers(),
      rustler_crates: [
        ryugraph_nif: [
          path: "native/ryugraph_nif",
          mode: rustc_mode(Mix.env())
        ]
      ],

      # Hex.pm package metadata
      description: "Elixir NIF bindings for RyuGraph - an embedded property graph database with Cypher query support",
      package: package(),

      # Documentation
      name: "RyugraphEx",
      source_url: "https://github.com/tylerdavis/ryugraph_ex",
      homepage_url: "https://github.com/tylerdavis/ryugraph_ex",
      docs: [
        main: "RyugraphEx",
        extras: ["README.md", "CHANGELOG.md"],
        groups_for_modules: [
          "Core": [RyugraphEx, RyugraphEx.Database, RyugraphEx.Connection],
          "Graph Operations": [RyugraphEx.Graph],
          "Schema Management": [RyugraphEx.Schema],
          "Internal": [RyugraphEx.Native]
        ]
      ]
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
      {:rustler, "~> 0.35.0", runtime: false},
      {:ex_doc, "~> 0.34.0", only: :dev, runtime: false}
    ]
  end

  defp rustc_mode(:prod), do: :release
  defp rustc_mode(_), do: :debug

  defp package do
    [
      name: "ryugraph_ex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/tylerdavis/ryugraph_ex",
        "RyuGraph" => "https://github.com/predictable-labs/ryugraph",
        "RyuGraph Website" => "https://www.ryugraph.io"
      },
      files: ~w(
        lib
        native/ryugraph_nif/src
        native/ryugraph_nif/Cargo.toml
        native/ryugraph_nif/Cargo.lock
        mix.exs
        README.md
        CHANGELOG.md
        LICENSE
        .formatter.exs
      ),
      maintainers: ["Tyler Davis"]
    ]
  end
end
