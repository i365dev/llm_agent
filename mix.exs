defmodule LLMAgent.MixProject do
  use Mix.Project

  def project do
    [
      app: :llm_agent,
      version: "3.0.0",
      elixir: "~> 1.18",
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
      extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("guides/*.md"),
      source_url: "https://github.com/i365dev/llm_agent",
      formatters: ["html"],
      groups_for_extras: [
        Guides: Path.wildcard("guides/*.md")
      ],
      groups_for_modules: [
        Core: [
          LLMAgent,
          LLMAgent.Signals,
          LLMAgent.Handlers,
          LLMAgent.Store,
          LLMAgent.Flows
        ],
        "LLM Providers": [
          LLMAgent.Providers.OpenAI,
          LLMAgent.Providers.Anthropic
        ],
        Plugins: [
          LLMAgent.Plugin
        ],
        Tasks: [
          LLMAgent.Tasks
        ]
      ],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({startOnLoad:true});</script>
    """
  end
end
