defmodule LLMAgent.MixProject do
  use Mix.Project

  def project do
    [
      app: :llm_agent,
      version: "3.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {LLMAgent.Application, []}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies
  defp deps do
    [
      {:agent_forge, "~> 0.2.0"},
      {:jason, "~> 1.4"},
      {:openai, "~> 0.5.2"},
      {:anthropic, "~> 0.1.0"},
      {:finch, "~> 0.16.0"},
      # Development and test dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["test"],
      lint: ["format", "credo --strict"],
      docs: ["docs"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      formatters: ["html"]
    ]
  end
end
