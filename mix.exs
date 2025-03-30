defmodule LLMAgent.MixProject do
  use Mix.Project

  @source_url "https://github.com/i365dev/llm_agent"
  @version "0.2.0"

  def project do
    [
      app: :llm_agent,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        "test.examples": :test
      ],
      description:
        "An abstraction library for building domain-specific intelligent agents based on Large Language Models",
      package: package(),
      homepage_url: @source_url,
      source_url: @source_url
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
      {:agent_forge, "~> 0.2.2"},
      {:jason, "~> 1.4"},
      {:openai, "~> 0.5.2"},
      {:anthropic, "~> 0.1.0"},
      {:finch, "~> 0.16.0"},
      {:excoveralls, "~> 0.18", only: :test},
      # Development and test dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      # Run standard tests and then run examples
      test: ["test", &run_examples/1],
      # Run only the examples files
      "test.examples": [&run_examples/1],
      lint: ["format", "credo --strict"]
    ]
  end

  # Custom function to run all example files in the examples directory
  defp run_examples(_) do
    IO.puts("\n=== Running examples ===\n")

    # Find all .exs files in the examples directory
    examples = Path.wildcard("examples/**/*.exs")

    # Run each example file
    Enum.each(examples, fn example_file ->
      relative_path = Path.relative_to_cwd(example_file)
      IO.puts("Running example: #{relative_path}")

      try do
        # Capture output to avoid cluttering the test results
        ExUnit.CaptureIO.capture_io(fn ->
          Code.eval_file(example_file)
        end)

        IO.puts("✓ Example #{relative_path} completed successfully\n")
      rescue
        e ->
          IO.puts("✗ Example #{relative_path} failed with error: #{inspect(e)}\n")
          Mix.raise("Example failed: #{relative_path}")
      end
    end)

    IO.puts("=== Finished running examples ===\n")
  end

  defp docs do
    [
      main: "readme",
      extras:
        ["README.md", "CHANGELOG.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "LICENSE"] ++
          Path.wildcard("guides/*.md"),
      source_url: @source_url,
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

  defp package do
    [
      name: "llm_agent",
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({startOnLoad:true});</script>
    """
  end
end
