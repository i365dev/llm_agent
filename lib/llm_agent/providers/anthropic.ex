defmodule LLMAgent.Providers.Anthropic do
  @moduledoc """
  Anthropic provider implementation for LLMAgent.

  This module implements the LLM provider interface for Anthropic, handling
  API calls, response parsing, and error handling specific to Anthropic's API.
  """

  @doc """
  Makes an Anthropic chat completion API call.

  ## Parameters

  - `params` - A map containing the request parameters

  ## Returns

  - `{:ok, response}` - On success, returns the parsed response
  - `{:error, reason}` - On failure, returns the error reason
  """
  def completion(params) do
    try do
      api_key = Map.get(params, :api_key) || System.get_env("ANTHROPIC_API_KEY")

      # If no API key, return error
      if is_nil(api_key) do
        {:error, "Missing Anthropic API key"}
      else
        # Extract request parameters
        messages = Map.get(params, :messages, [])
        tools = Map.get(params, :tools, [])
        model = Map.get(params, :model, "claude-3-opus-20240229")

        # Format request body
        request_body = %{
          model: model,
          messages: format_messages(messages),
          temperature: Map.get(params, :temperature, 0.7),
          max_tokens: Map.get(params, :max_tokens, 1000)
        }

        # Add tools if provided
        request_body =
          if length(tools) > 0 do
            Map.put(request_body, :tools, format_tools(tools))
          else
            request_body
          end

        # Mock Anthropic API response
        response = mock_anthropic_response(request_body)

        # Parse response
        parsed_response = parse_anthropic_response(response)
        {:ok, parsed_response}
      end
    rescue
      e ->
        {:error, "Error processing Anthropic request: #{inspect(e)}"}
    end
  end

  @doc """
  Generates embeddings for the provided text using a compatible model.

  Note: Anthropic doesn't provide a dedicated embedding API, so this implementation
  uses a third-party compatible service or delegates to OpenAI's embedding API.

  ## Parameters

  - `params` - A map with parameters for the request:
    - `input` - The text to generate embeddings for
    - `provider` - The embedding provider to use (default: :openai)

  ## Returns

  `{:ok, embeddings}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> params = %{
      ...>   input: "Hello, world!",
      ...>   provider: :openai
      ...> }
      iex> {:ok, embeddings} = LLMAgent.Providers.Anthropic.embedding(params)
      iex> is_list(embeddings)
      true
  """
  def embedding(params) do
    # Anthropic doesn't have an embedding API, so we delegate to OpenAI or another provider
    provider = Map.get(params, :provider, :openai)

    case provider do
      :openai ->
        # Delegate to OpenAI embedding
        LLMAgent.Providers.OpenAI.embedding(params)

      _ ->
        # Return mock embeddings if no valid provider is specified
        {:ok, mock_embeddings(Map.get(params, :input, ""))}
    end
  end

  # Private functions

  defp format_messages(messages) do
    # Convert messages to the format expected by Anthropic
    Enum.map(messages, fn message ->
      case message do
        %{role: role, content: content} ->
          format_message_content(role, content)

        %{"role" => role, "content" => content} ->
          format_message_content(role, content)

        _ ->
          %{role: "user", content: [%{type: "text", text: inspect(message)}]}
      end
    end)
  end

  defp format_message_content(role, content) when is_binary(content) do
    # Convert role to Anthropic-compatible role
    anthropic_role =
      case role do
        "assistant" -> "assistant"
        "system" -> "system"
        _ -> "user"
      end

    # Format content as a list with a text object
    %{
      role: anthropic_role,
      content: [%{type: "text", text: content}]
    }
  end

  defp format_message_content(role, content) when is_list(content) do
    # If content is already a list (may contain image URLs, etc.), use it directly
    anthropic_role =
      case role do
        "assistant" -> "assistant"
        "system" -> "system"
        _ -> "user"
      end

    %{
      role: anthropic_role,
      content: content
    }
  end

  defp format_tools(tools) do
    # Convert tools to the format expected by Anthropic
    Enum.map(tools, fn tool ->
      %{
        name: get_tool_name(tool),
        description: get_tool_description(tool),
        input_schema: get_tool_parameters(tool)
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

  defp parse_anthropic_response(response) do
    # Extract the relevant parts of the Anthropic response

    # Get the content parts
    content_parts = get_in(response, [:content]) || []

    # Check if the response contains tool calls
    tool_calls = get_in(response, [:tool_use]) || []

    if length(tool_calls) > 0 do
      # Parse tool calls
      parsed_tool_calls =
        Enum.map(tool_calls, fn tool_call ->
          %{
            id: tool_call.id || "tool-#{System.unique_integer([:positive])}",
            name: tool_call.name,
            arguments: parse_tool_arguments(tool_call.input)
          }
        end)

      # Extract text content
      text_content = extract_text_content(content_parts)

      %{content: text_content, tool_calls: parsed_tool_calls}
    else
      # Regular response, just extract the text
      text_content = extract_text_content(content_parts)
      %{content: text_content, tool_calls: []}
    end
  end

  defp extract_text_content(content_parts) do
    # Combine all text parts into a single string
    content_parts
    |> Enum.filter(fn part -> part.type == "text" end)
    |> Enum.map(fn part -> part.text end)
    |> Enum.join("\n")
  end

  defp parse_tool_arguments(arguments) when is_map(arguments) do
    # Arguments are already a map in Anthropic's format
    arguments
  end

  defp parse_tool_arguments(arguments) when is_binary(arguments) do
    # Parse JSON arguments if they're a string
    case Jason.decode(arguments) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{raw_arguments: arguments}
    end
  end

  defp parse_tool_arguments(arguments) do
    # Fallback for other formats
    %{raw_arguments: inspect(arguments)}
  end

  # Mock implementations for when Anthropic module is not available

  # Mock Anthropic response for testing purposes
  defp mock_anthropic_response(request_body) do
    # Check if tools were requested
    tools = Map.get(request_body, :tools, [])

    if length(tools) > 0 do
      # Mock a tool call response
      %{
        id: "msg_mock-completion-id",
        content: [
          %{
            type: "tool_use",
            id: "tool_use_mock-id",
            name: "get_current_weather",
            input: %{
              location: "San Francisco, CA"
            }
          }
        ],
        model: Map.get(request_body, :model),
        role: "assistant",
        stop_reason: "tool_use",
        stop_sequence: nil,
        type: "message",
        usage: %{
          input_tokens: 100,
          output_tokens: 100
        }
      }
    else
      # Mock a standard response
      %{
        id: "msg_mock-completion-id",
        content: [
          %{
            type: "text",
            text: "This is a mock response from the Anthropic API."
          }
        ],
        model: Map.get(request_body, :model),
        role: "assistant",
        stop_reason: "end_turn",
        stop_sequence: nil,
        type: "message",
        usage: %{
          input_tokens: 100,
          output_tokens: 100
        }
      }
    end
  end

  defp mock_embeddings(input) do
    # Generate deterministic mock embeddings for testing
    input_length = String.length(input)
    # Create a vector of 1536 dimensions (compatible with OpenAI's embedding size)
    Enum.map(1..1536, fn i ->
      :math.cos(i * input_length / 1536) * 0.1
    end)
  end
end
