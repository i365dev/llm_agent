defmodule LLMAgent do
  @moduledoc """
  LLMAgent is an abstraction library for building domain-specific intelligent agents based on 
  Large Language Models (LLMs). It provides a core architecture and behavior definitions 
  that simplify the development of specialized agents.

  LLMAgent is built on top of AgentForge's signal-driven architecture and provides
  LLM-specific interaction patterns, signal types, message processing handlers,
  tool integration, and conversation management.

  ## Key Features

  - LLM-specific signal types for agent interactions
  - Predefined handlers for processing LLM signals
  - Standard flow compositions for common agent patterns
  - Plugin-based extensions for LLM providers
  - Task management for long-running operations

  ## Usage Example

  ```elixir
  # Create agent with system prompt and basic tools
  {flow, initial_state} = LLMAgent.Flows.conversation(
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
  {:ok, result, new_state} = AgentForge.process(
    flow,
    LLMAgent.Signals.user_message("What is the capital of France?"),
    initial_state
  )
  ```
  """

  @doc """
  Returns the current version of LLMAgent.

  ## Examples

      iex> LLMAgent.version()
      "3.0.0"
  """
  def version, do: "3.0.0"

  @doc """
  Creates a new LLM agent with the given system prompt and tools.

  This is a convenience function that creates a flow and initial state for a conversational agent.

  ## Parameters

  - `system_prompt` - The system prompt that defines the agent's behavior
  - `tools` - A list of tools that the agent can use
  - `options` - Additional options for configuring the agent

  ## Returns

  A tuple containing the flow and initial state for the agent.

  ## Examples

      iex> {flow, state} = LLMAgent.new("You are a helpful assistant.", [])
      iex> is_function(flow) and is_map(state)
      true
  """
  def new(system_prompt, tools \\ [], options \\ []) do
    LLMAgent.Flows.conversation(system_prompt, tools, options)
  end

  @doc """
  Processes a user message through an LLM agent flow.

  This is a convenience function that creates a user message signal and processes it through the agent flow.

  ## Parameters

  - `flow` - The agent flow to process the message through
  - `state` - The current state of the agent
  - `message` - The user message to process
  - `options` - Additional options for processing the message

  ## Returns

  A tuple containing the result of processing the message and the new state.

  ## Examples

      iex> {flow, state} = LLMAgent.new("You are a helpful assistant.", [])
      iex> {:ok, result, _} = LLMAgent.process(flow, state, "Hello")
      iex> result.type == :response
      true
  """
  def process(flow, state, message, options \\ []) do
    signal = LLMAgent.Signals.user_message(message)
    timeout = Keyword.get(options, :timeout, 30_000)

    AgentForge.Flow.process_with_limits(flow, signal, state, timeout_ms: timeout)
  end
end
