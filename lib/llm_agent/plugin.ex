defmodule LLMAgent.Plugin do
  @moduledoc """
  Implements the AgentForge.Plugin behavior for LLM integrations.

  This module provides a plugin implementation that registers LLM-specific tools
  and allows LLMAgent to integrate with different LLM providers.
  """

  @behaviour AgentForge.Plugin

  @doc """
  Initializes the LLMAgent plugin.

  Checks that required dependencies are available for the specified provider.

  ## Parameters

  - `opts` - Plugin options including provider selection

  ## Returns

  `:ok` if initialization succeeds, `{:error, reason}` otherwise.

  ## Examples

      iex> LLMAgent.Plugin.init(provider: :mock)
      :ok
  """
  @impl true
  def init(opts) do
    # Check that required dependencies are available
    provider = Keyword.get(opts, :provider, :openai)

    case provider do
      # For demonstration purposes, we'll use a mock provider
      :mock ->
        :ok

      :openai ->
        # Check if OpenAI is available
        if Code.ensure_loaded?(OpenAI) do
          :ok
        else
          {:error,
           "OpenAI dependency not installed. Add {:openai, \"~> 0.5.0\"} to your dependencies."}
        end

      :anthropic ->
        # Check if Anthropic is available
        if Code.ensure_loaded?(Anthropic) do
          :ok
        else
          {:error,
           "Anthropic dependency not installed. Add {:anthropic, \"~> 0.1.0\"} to your dependencies."}
        end

      _ ->
        {:error, "Unsupported provider: #{provider}"}
    end
  end

  @doc """
  Registers LLM-specific tools with AgentForge.

  ## Parameters

  - `registry` - The AgentForge tool registry

  ## Returns

  `:ok` if registration succeeds.
  """
  @impl true
  def register_tools(registry) do
    registry.register("llm_call", &call_llm/1)
    registry.register("parse_response", &parse_llm_response/1)
    :ok
  end

  @doc """
  Registers LLM-specific primitives with AgentForge.

  ## Returns

  `:ok` if registration succeeds.
  """
  @impl true
  def register_primitives do
    # No primitives to register for now
    :ok
  end

  @doc """
  Returns metadata about the LLMAgent plugin.

  ## Returns

  A map with plugin metadata.
  """
  @impl true
  def metadata do
    %{
      name: "LLMAgent Plugin",
      description: "Provides LLM integration for AgentForge",
      version: "3.0.0",
      author: "i365dev",
      compatible_versions: ">= 0.2.0"
    }
  end

  # Tool implementations

  @doc """
  Calls an LLM provider with the given parameters.

  ## Parameters

  - `params` - A map with parameters:
    - `provider` - The LLM provider to use (e.g., :openai, a module)
    - `messages` - The conversation messages
    - `tools` - Available tools for the LLM
    - `options` - Provider-specific options

  ## Returns

  A map with the LLM response.
  """
  def call_llm(params) do
    provider = Map.get(params, "provider", :openai)
    messages = Map.get(params, "messages", [])
    tools = Map.get(params, "tools", [])
    options = Map.get(params, "options", %{})

    cond do
      is_atom(provider) and Code.ensure_loaded?(provider) and
          function_exported?(provider, :generate_response, 2) ->
        try do
          provider.generate_response(messages, Map.put(options, :tools, tools))
        rescue
          e ->
            require Logger
            Logger.error("Error calling module provider #{inspect(provider)}: #{inspect(e)}")
            %{error: "Provider error: #{Exception.message(e)}"}
        end

      provider == :openai ->
        call_openai(messages, tools, options)

      provider == :anthropic ->
        call_anthropic(messages, tools, options)

      provider == :mock ->
        mock_llm_response(messages, tools, options)

      true ->
        %{error: "Unsupported provider: #{inspect(provider)}"}
    end
  end

  @doc """
  Parses an LLM response into a structured format.

  ## Parameters

  - `params` - A map with parameters:
    - `response` - The raw LLM response
    - `format` - The desired output format

  ## Returns

  A structured representation of the LLM response.
  """
  def parse_llm_response(params) do
    response = Map.get(params, "response", "")
    format = Map.get(params, "format", "json")

    case format do
      "json" ->
        case Jason.decode(response) do
          {:ok, parsed} -> parsed
          {:error, _} -> %{text: response, parsed: false}
        end

      "text" ->
        %{text: response}

      _ ->
        %{text: response, format: "unknown"}
    end
  end

  # Provider implementations

  defp call_openai(_messages, _tools, _options) do
    # In a real implementation, this would call the OpenAI API
    # For now, we'll return a mock response
    %{
      choices: [
        %{
          message: %{
            role: "assistant",
            content: "This is a mock OpenAI response.",
            tool_calls: []
          }
        }
      ]
    }
  end

  defp call_anthropic(_messages, _tools, _options) do
    # In a real implementation, this would call the Anthropic API
    # For now, we'll return a mock response
    %{
      content: [
        %{
          type: "text",
          text: "This is a mock Anthropic response."
        }
      ]
    }
  end

  defp mock_llm_response(messages, tools, _options) do
    # Create a simple mock response
    last_message =
      messages
      |> Enum.reverse()
      |> Enum.find(fn msg -> msg["role"] == "user" end)
      |> Map.get("content", "")

    cond do
      # If the message mentions a tool and tools are available
      String.contains?(last_message, "weather") and
          Enum.any?(tools, &(&1["name"] == "get_weather")) ->
        %{
          type: "tool_call",
          tool: "get_weather",
          args: %{city: "New York"}
        }

      # If the message is a question
      String.contains?(last_message, "?") ->
        question = String.trim(last_message)

        answer =
          case question do
            "What is the capital of France?" -> "The capital of France is Paris."
            "How are you?" -> "I'm a mock LLM, but I'm doing well! How can I help you today?"
            _ -> "I don't have a specific answer for that question in my mock responses."
          end

        %{
          type: "response",
          content: answer
        }

      # Default thinking response
      true ->
        %{
          type: "thinking",
          thought: "I need to process the user's request: #{last_message}"
        }
    end
  end
end
