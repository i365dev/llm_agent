# LLMAgent

[![CI](https://github.com/i365dev/llm_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/i365dev/llm_agent/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/llm_agent.svg)](https://hex.pm/packages/llm_agent)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/llm_agent)
[![License](https://img.shields.io/badge/license-MIT-blue)](https://github.com/i365dev/llm_agent/blob/main/LICENSE)

LLMAgent is an abstraction library for building domain-specific intelligent agents based on Large Language Models (LLMs). Built on top of AgentForge's signal-driven architecture, LLMAgent provides specialized patterns for LLM-powered agents, including predefined signals, handlers, store structures, and flows optimized for conversational agents.

## Features

- 🧠 LLM-specific interaction patterns and signal types
- 🔀 Message processing workflows and handlers
- 🛠️ Tool integration and execution
- ⏱️ Long-running task management
- 💬 Context and conversation management
- 🔌 Plugin-based provider integrations
- 🔄 AgentForge compatibility
- 🌊 **Dynamic workflow orchestration** - Enable LLMs to create multi-step workflows based on context

## Installation

Add `llm_agent` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:llm_agent, "~> 0.1.1"},
    # Optional LLM provider dependencies
    {:openai, "~> 0.5.0"}, # If using OpenAI
    {:anthropic, "~> 0.1.0"} # If using Anthropic
  ]
end
```

## Quick Start

```elixir
# Create agent with system prompt and basic tools
{flow, initial_state} = LLMAgent.new(
  "You are a helpful assistant that can answer questions and use tools.",
  [
    %{
      name: "search",
      description: "Search the web for information",
      parameters: %{
        "type" => "object",
        "properties" => %{
          "query" => %{
            "type" => "string",
            "description" => "Search query"
          }
        },
        "required" => ["query"]
      },
      execute: &MyApp.Tools.search/1
    }
  ]
)

# Process a user message
{:ok, result, new_state} = LLMAgent.process(flow, initial_state, "What is the capital of France?")

# Handle result
case result do
  %{type: :response, data: content} ->
    IO.puts("Agent response: #{content}")
    
  %{type: :thinking, data: thought} ->
    IO.puts("Agent thinking: #{thought}")
    
  %{type: :error, data: %{message: message}} ->
    IO.puts("Error: #{message}")
end
```

## Core Components

### Signals

LLMAgent defines specialized signal types for LLM interactions:

```elixir
# Create a user message signal
signal = LLMAgent.Signals.user_message("Help me analyze AAPL stock")

# Create a thinking signal
thinking = LLMAgent.Signals.thinking("I need to get stock price data", 1)

# Create a tool call signal
tool_call = LLMAgent.Signals.tool_call("get_stock_price", %{ticker: "AAPL"})
```

### Handlers

Handlers process LLM-specific signals:

```elixir
# Message handler processes user messages
LLMAgent.Handlers.message_handler(signal, state)

# Tool handler executes tool calls
LLMAgent.Handlers.tool_handler(tool_call, state)
```

### Store

Manage conversation state:

```elixir
# Create a new store
state = LLMAgent.Store.new()

# Add a message to history
state = LLMAgent.Store.add_message(state, "user", "Hello")

# Get conversation history
history = LLMAgent.Store.get_llm_history(state)
```

### Flows

Create standard workflow compositions:

```elixir
# Create a conversation flow with tools
{flow, state} = LLMAgent.Flows.conversation(system_prompt, tools)

# Create a simple QA agent
{flow, state} = LLMAgent.Flows.qa_agent(system_prompt)
```

### Tasks

Manage long-running operations:

```elixir
# Define a task with AgentForge primitives
task_def = [
  AgentForge.Primitives.transform(fn data -> Map.put(data, :processed, true) end)
]

# Start the task
{task_id, signal} = LLMAgent.Tasks.start(task_def, params, state)
```

## LLM Providers

LLMAgent supports multiple LLM providers through its plugin system:

```elixir
# Use OpenAI for completions
{:ok, response} = LLMAgent.Providers.OpenAI.completion(%{
  model: "gpt-4",
  messages: [%{role: "user", content: "Hello"}],
  max_tokens: 500
})

# Use Anthropic for completions
{:ok, response} = LLMAgent.Providers.Anthropic.completion(%{
  model: "claude-3-opus-20240229",
  messages: [%{role: "user", content: "Hello"}],
  max_tokens: 500
})
```

## Domain-Specific Agents

Build specialized agents by:

1. Creating domain-specific handlers
2. Registering domain-specific tools
3. Defining domain-specific tasks
4. Creating domain-specific flows

```elixir
defmodule MyApp.InvestmentAgent do
  def new(options \\ %{}) do
    # Define system prompt
    system_prompt = "You are an AI investment assistant..."
    
    # Define investment tools
    tools = [
      %{
        name: "get_stock_price",
        description: "Get current price for a stock",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "ticker" => %{
              "type" => "string",
              "description" => "Stock ticker symbol"
            }
          },
          "required" => ["ticker"]
        },
        execute: &MyApp.Tools.get_stock_price/1
      }
    ]
    
    # Create agent flow
    LLMAgent.new(system_prompt, tools, options)
  end
end
```

## Additional Documentation

- [Getting Started Guide](https://hexdocs.pm/llm_agent/getting_started.html)
- [Architecture Guide](https://hexdocs.pm/llm_agent/architecture.html)
- [Tool Integration](https://hexdocs.pm/llm_agent/tool_integration.html)
- [Custom Agents](https://hexdocs.pm/llm_agent/custom_agents.html)
- [API Reference](https://hexdocs.pm/llm_agent/api-reference.html)

## Examples

- Simple conversation agent: [Simple QA Agent](examples/simple_qa_agent.exs)
- Tool-using agent: [Tool Using Agent](examples/tool_using_agent.exs)
- Complex domain-specific agent: [Investment Portfolio Advisor](examples/investment_portfolio.exs)

## Contributing

We welcome contributions from the community! Please see our [Contributing Guide](CONTRIBUTING.md) for more information on how to get involved.

## License

LLMAgent is released under the MIT License. See the [LICENSE](LICENSE) file for details.