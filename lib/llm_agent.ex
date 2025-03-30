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
  Process a user message through an agent flow.

  ## Parameters

  - `flow` - Flow to process the message with (function or list of handlers)
  - `state` - Current agent state
  - `message` - User message to process
  - `options` - Processing options

  ## Returns

  Result of processing the message through the flow.

  ## Examples

      iex> {flow, state} = LLMAgent.new("You are a helpful assistant.", [])
      iex> {:ok, result, _} = LLMAgent.process(flow, state, "Hello")
      iex> result.type == :response
      true
  """
  def process(flow, state, message, options \\ []) do
    require Logger

    signal = LLMAgent.Signals.user_message(message)
    Logger.debug("LLMAgent.process - Input signal: #{inspect(signal)}")
    Logger.debug("LLMAgent.process - Initial state: #{inspect(state)}")

    # Set default options for processing
    flow_options = [
      # Allow handlers to skip without terminating the chain
      continue_on_skip: true,
      # Forward emitted signals to next handler
      signal_strategy: :forward,
      timeout_ms: Keyword.get(options, :timeout_ms, 30_000),
      return_stats: Keyword.get(options, :return_stats, false)
    ]

    # Execute the flow based on its type
    flow_type = type_of(flow)
    Logger.debug("LLMAgent.process - Executing flow (type: #{inspect(flow_type)})")

    result =
      case flow_type do
        "function" ->
          # Use the new process_function_flow API for function flows
          AgentForge.Flow.process_function_flow(flow, signal, state, flow_options)

        "list" ->
          # Use process_with_limits for handler lists
          AgentForge.Flow.process_with_limits(flow, signal, state, flow_options)

        _ ->
          Logger.error("LLMAgent.process - Unknown flow type: #{inspect(flow)}")
          {:error, "Unknown flow type", state}
      end

    Logger.debug("LLMAgent.process - Flow result: #{inspect(result)}")

    # Handle potential nil results from skipped handlers
    case result do
      {:ok, nil, new_state} ->
        # Create a default response when all handlers skipped
        default_response = LLMAgent.Signals.response("No handler processed this message")
        {:ok, default_response, new_state}

      _ ->
        result
    end
  end

  # Helper to determine the type of flow for debugging
  defp type_of(flow) when is_function(flow), do: "function"
  defp type_of(flow) when is_list(flow), do: "list"
  defp type_of(_), do: "unknown"
end
