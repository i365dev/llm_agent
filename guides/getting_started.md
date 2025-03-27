# Getting Started with LLMAgent

LLMAgent is an abstraction library built on top of AgentForge that specializes in LLM-powered agent interactions. This guide will help you get started with LLMAgent quickly.

## Installation

Add LLMAgent to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:llm_agent, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

Configure your LLM provider API keys in your config:

```elixir
# config/config.exs
config :llm_agent, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization_id: System.get_env("OPENAI_ORGANIZATION_ID")

config :llm_agent, :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY")
```

## Creating Your First Agent

Creating a basic question-answering agent requires only a few lines of code:

```elixir
# Create a simple Q&A agent with a system prompt
{flow, state} = LLMAgent.Flows.conversation(
  "You are a helpful assistant that answers questions concisely."
)

# Process a user message
message = "What is Elixir?"
{:ok, result, new_state} = AgentForge.process(flow, state, LLMAgent.Signals.user_message(message))

# Extract the assistant response
response = result.data
IO.puts("Assistant: #{response}")
```

## Adding Tools

Agents become more powerful when they can use tools to access external information or perform actions:

```elixir
# Define some tools
tools = [
  %{
    name: "calculator",
    description: "Perform mathematical calculations",
    execute: fn args -> 
      expr = args["expression"]
      {:ok, result} = Code.eval_string(expr)
      %{result: result}
    end
  },
  %{
    name: "current_time",
    description: "Get the current time",
    execute: fn _args -> 
      %{time: DateTime.utc_now() |> DateTime.to_string()}
    end
  }
]

# Create an agent with tools
{flow, state} = LLMAgent.Flows.conversation(
  "You are a helpful assistant that can perform calculations and tell the time.",
  tools
)

# Process a message that might require a tool
message = "What's 22 + 20?"
{:ok, result, new_state} = AgentForge.process(flow, state, LLMAgent.Signals.user_message(message))
```

## Next Steps

- Learn about the [architecture](architecture.html) of LLMAgent
- Discover how to integrate [custom tools](tool_integration.html)
- Explore [domain-specific agents](custom_agents.html)
