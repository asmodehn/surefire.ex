defmodule Surefire.MixProject do
  use Mix.Project

  def project do
    [
      app: :surefire,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,

      # options
      elixirc_paths: elixirc_paths(Mix.env()),
      # [warnings_as_errors: true],
      elixirc_options: [],
      deps: deps(),

      # Docs
      name: "Surefire",
      source_url: "https://github.com/asmodehn/surefire.ex",
      #    homepage_url: "http://YOUR_PROJECT_HOMEPAGE",
      docs: [
        # The main page in the docs
        main: "Surefire",
        #      logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Surefire.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  # to be able to interactively use test/usage
  defp elixirc_paths(:test), do: ["lib", "examples", "test/support"]
  defp elixirc_paths(_), do: ["lib", "examples"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:math, " ~> 0.7"},
      {:ex_prompt, "~> 0.1.5"},
      {:exqlite, "~> 0.13"},
      {:gen_state_machine, "3.0.0"},
      {:table, "~> 0.1.2"},
      {:table_rex, "~> 4.0.0"},
      {:ulid, git: "https://github.com/asmodehn/ulid", branch: "master"},

      # test dependencies
      {:stream_data, "~> 0.6", only: [:dev, :test], runtime: false},

      # dev tools
      {:committee, "~> 1.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
