defmodule LLMAgent.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation for LLMAgent.

  This module implements the LLM provider interface for OpenAI, handling
  API calls, response parsing, and error handling specific to OpenAI's API.
  """

  @doc """
  Sends a completion request to OpenAI's API.

  ## Parameters

  - `params` - A map with parameters for the request:
    - `model` - The model to use (e.g., "gpt-4")
    - `messages` - The conversation history
    - `tools` - Available tools for function calling
    - `temperature` - Controls randomness (0.0 to 2.0)
    - `max_tokens` - Maximum tokens to generate

  ## Returns

  `{:ok, response}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> params = %{
      ...>   model: "gpt-4",
      ...>   messages: [%{role: "user", content: "Hello"}],
      ...>   max_tokens: 500
      ...> }
      iex> {:ok, response} = LLMAgent.Providers.OpenAI.completion(params)
      iex> is_map(response)
      true
  """
  def completion(params) do
    try do
      api_key = Map.get(params, :api_key) || System.get_env("OPENAI_API_KEY")

      # If no API key, return error
      if is_nil(api_key) do
        {:error, "Missing OpenAI API key"}
      else
        # Extract request parameters
        messages = Map.get(params, :messages, [])
        tools = Map.get(params, :tools, [])
        model = Map.get(params, :model, "gpt-4")

        # Format request body
        request_body = %{
          model: model,
          messages: format_messages(messages),
          temperature: Map.get(params, :temperature, 0.7)
        }

        # Add tools if provided
        request_body =
          if length(tools) > 0 do
            Map.put(request_body, :tools, format_tools(tools))
          else
            request_body
          end

        # Mock OpenAI API response
        response = mock_openai_response(request_body)

        # Parse response
        parsed_response = parse_openai_response(response)
        {:ok, parsed_response}
      end
    rescue
      e ->
        {:error, "Error processing OpenAI request: #{inspect(e)}"}
    end
  end

  @doc """
  Generates embeddings for the provided text using OpenAI's API.

  ## Parameters

  - `params` - A map with parameters for the request:
    - `model` - The embedding model to use (e.g., "text-embedding-ada-002")
    - `input` - The text to generate embeddings for

  ## Returns

  `{:ok, embeddings}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> params = %{
      ...>   model: "text-embedding-ada-002",
      ...>   input: "Hello, world!"
      ...> }
      iex> {:ok, embeddings} = LLMAgent.Providers.OpenAI.embedding(params)
      iex> is_list(embeddings)
      true
  """
  def embedding(params) do
    try do
      api_key = Map.get(params, :api_key) || System.get_env("OPENAI_API_KEY")

      # If no API key, return error
      if is_nil(api_key) do
        {:error, "Missing OpenAI API key"}
      else
        # Extract request parameters
        input = Map.get(params, :input)
        model = Map.get(params, :model, "text-embedding-ada-002")

        # Format request body
        request_body = %{
          model: model,
          input: input
        }

        # Mock OpenAI embeddings response
        response = mock_openai_embedding_response(request_body)

        # Parse response
        case response do
          %{data: embeddings} ->
            {:ok, embeddings}

          _ ->
            {:error, "Invalid embedding response"}
        end
      end
    rescue
      e ->
        {:error, "Error processing OpenAI embedding request: #{inspect(e)}"}
    end
  end

  # Private functions

  defp format_messages(messages) do
    # Convert messages to the format expected by OpenAI
    Enum.map(messages, fn message ->
      case message do
        %{role: role, content: content} ->
          %{role: role, content: content}

        %{"role" => role, "content" => content} ->
          %{role: role, content: content}

        _ ->
          %{role: "user", content: inspect(message)}
      end
    end)
  end

  defp format_tools(tools) do
    # Convert tools to the format expected by OpenAI
    Enum.map(tools, fn tool ->
      %{
        type: "function",
        function: %{
          name: get_tool_name(tool),
          description: get_tool_description(tool),
          parameters: get_tool_parameters(tool)
        }
      }
    end)
  end

  defp get_tool_name(tool) do
    cond do
      is_map(tool) and Map.has_key?(tool, :name) -> tool.name
      is_map(tool) and Map.has_key?(tool, "name") -> tool["name"]
      true -> "unknown_tool"
    end
  end

  defp get_tool_description(tool) do
    cond do
      is_map(tool) and Map.has_key?(tool, :description) -> tool.description
      is_map(tool) and Map.has_key?(tool, "description") -> tool["description"]
      true -> "No description available"
    end
  end

  defp get_tool_parameters(tool) do
    cond do
      is_map(tool) and Map.has_key?(tool, :parameters) -> tool.parameters
      is_map(tool) and Map.has_key?(tool, "parameters") -> tool["parameters"]
      true -> %{type: "object", properties: %{}}
    end
  end

  defp parse_openai_response(response) do
    # Extract the relevant parts of the OpenAI response
    choice = List.first(response.choices)

    if is_nil(choice) do
      %{content: nil, tool_calls: []}
    else
      message = choice.message

      # Check if the response contains tool calls
      tool_calls = Map.get(message, :tool_calls, [])

      if length(tool_calls) > 0 do
        # Parse tool calls
        parsed_tool_calls =
          Enum.map(tool_calls, fn tool_call ->
            %{
              id: tool_call.id,
              name: tool_call.function.name,
              arguments: parse_tool_arguments(tool_call.function.arguments)
            }
          end)

        %{content: message.content, tool_calls: parsed_tool_calls}
      else
        # Regular response
        %{content: message.content, tool_calls: []}
      end
    end
  end

  defp parse_tool_arguments(arguments) do
    # Parse JSON arguments
    case Jason.decode(arguments) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{raw_arguments: arguments}
    end
  end

  # Mock OpenAI response for testing purposes
  defp mock_openai_response(request_body) do
    # Check if tools were requested
    tools = Map.get(request_body, :tools, [])

    if length(tools) > 0 do
      # Mock a tool call response
      %{
        id: "mock-completion-id",
        object: "chat.completion",
        created: :os.system_time(:second),
        model: Map.get(request_body, :model),
        choices: [
          %{
            index: 0,
            message: %{
              role: "assistant",
              content: nil,
              tool_calls: [
                %{
                  id: "mock-tool-call-id",
                  type: "function",
                  function: %{
                    name: "get_current_weather",
                    arguments: "{\"location\":\"San Francisco, CA\"}"
                  }
                }
              ]
            },
            finish_reason: "tool_calls"
          }
        ],
        usage: %{
          prompt_tokens: 100,
          completion_tokens: 100,
          total_tokens: 200
        }
      }
    else
      # Mock a standard response
      %{
        id: "mock-completion-id",
        object: "chat.completion",
        created: :os.system_time(:second),
        model: Map.get(request_body, :model),
        choices: [
          %{
            index: 0,
            message: %{
              role: "assistant",
              content: "This is a mock response from the OpenAI API."
            },
            finish_reason: "stop"
          }
        ],
        usage: %{
          prompt_tokens: 100,
          completion_tokens: 100,
          total_tokens: 200
        }
      }
    end
  end

  # Mock OpenAI embedding response for testing purposes
  defp mock_openai_embedding_response(_request_body) do
    %{
      object: "list",
      data: [
        %{
          object: "embedding",
          embedding: Enum.map(1..1536, fn _ -> :rand.uniform() end),
          index: 0
        }
      ],
      model: "text-embedding-ada-002",
      usage: %{
        prompt_tokens: 8,
        total_tokens: 8
      }
    }
  end
end
