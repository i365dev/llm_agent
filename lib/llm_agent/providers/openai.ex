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
    api_key = Map.get(params, :api_key) || System.get_env("OPENAI_API_KEY")

    # If no API key, return error
    if is_nil(api_key) do
      {:error,
       %{
         message: "Missing OpenAI API key",
         source: "openai_provider",
         context: %{params: params}
       }}
    else
      # Extract request parameters
      messages = Map.get(params, :messages, [])
      tools = Map.get(params, :tools, [])
      model = Map.get(params, :model, "gpt-4")
      max_retries = Map.get(params, :max_retries, 3)

      # Format request body
      request_body = %{
        model: model,
        messages: format_messages(messages),
        temperature: Map.get(params, :temperature, 0.7)
      }

      # Add tools if provided
      request_body =
        if length(tools) > 0 do
          Map.merge(request_body, %{
            tools: format_tools(tools),
            tool_choice: "auto"
          })
        else
          request_body
        end

      # Make API call with retry logic
      call_with_retry(
        fn ->
          OpenAI.chat_completion(
            request_body,
            api_key: api_key,
            http_options: [recv_timeout: 60_000]
          )
        end,
        max_retries
      )
      |> case do
        {:ok, response} ->
          # Parse response
          parse_openai_response(response, tools)

        {:error, %{status: status, body: body}} ->
          # Format error from HTTP response
          {:error,
           %{
             message: "OpenAI API error: #{inspect(body)}",
             source: "openai_provider",
             context: %{status: status, body: body}
           }}

        {:error, reason} ->
          # Format other errors
          {:error,
           %{
             message: "OpenAI API error: #{inspect(reason)}",
             source: "openai_provider",
             context: %{reason: reason}
           }}
      end
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
    api_key = Map.get(params, :api_key) || System.get_env("OPENAI_API_KEY")

    # If no API key, return error
    if is_nil(api_key) do
      {:error,
       %{
         message: "Missing OpenAI API key",
         source: "openai_provider",
         context: %{params: params}
       }}
    else
      # Extract request parameters
      input = Map.get(params, :input)
      model = Map.get(params, :model, "text-embedding-ada-002")
      max_retries = Map.get(params, :max_retries, 3)

      # Format request body
      request_body = %{
        model: model,
        input: input
      }

      # Make API call with retry logic
      response_result =
        call_with_retry(
          fn ->
            # 在实际实现中使用真实的 API 调用，现在使用模拟响应
            mock_openai_embedding_response(request_body)
          end,
          max_retries
        )

      # 处理响应结果
      handle_embedding_response(response_result)
    end
  end

  # 提取嵌套处理逻辑到单独函数
  defp handle_embedding_response({:ok, response}) do
    # 进一步处理成功响应
    extract_embeddings(response)
  end

  defp handle_embedding_response({:error, %{status: status, body: body}}) do
    # 格式化 HTTP 错误
    {:error,
     %{
       message: "OpenAI API error: #{inspect(body)}",
       source: "openai_provider",
       context: %{status: status, body: body}
     }}
  end

  # 提取嵌入向量
  defp extract_embeddings(%{data: embeddings}) do
    {:ok, embeddings}
  end

  defp extract_embeddings(response) do
    {:error,
     %{
       message: "Invalid embedding response format",
       source: "openai_provider",
       context: %{response: response}
     }}
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

  defp parse_openai_response(response, _tools) do
    # Extract the relevant parts of the OpenAI response
    choice = List.first(response.choices)

    # 提前返回，避免嵌套
    if is_nil(choice) do
      %{content: nil, tool_calls: []}
    else
      parse_choice(choice)
    end
  end

  # 提取出嵌套逻辑到单独的函数
  defp parse_choice(choice) do
    message = choice.message
    tool_calls = Map.get(message, :tool_calls, [])

    # 提取内容总是需要的
    content = message.content

    # 处理工具调用
    parsed_tool_calls = parse_tool_calls(tool_calls)

    %{content: content, tool_calls: parsed_tool_calls}
  end

  # 工具调用解析为单独函数
  defp parse_tool_calls([]), do: []

  defp parse_tool_calls(tool_calls) do
    Enum.map(tool_calls, fn tool_call ->
      %{
        id: tool_call.id,
        name: tool_call.function.name,
        arguments: parse_tool_arguments(tool_call.function.arguments)
      }
    end)
  end

  defp parse_tool_arguments(arguments) do
    # Parse JSON arguments
    case Jason.decode(arguments) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{raw_arguments: arguments}
    end
  end

  defp mock_openai_embedding_response(_request_body) do
    # 模拟 OpenAI 嵌入式响应
    {:ok, %{data: [%{embedding: [1.0, 2.0, 3.0]}]}}
  end

  # Retry logic for API calls with exponential backoff
  defp call_with_retry(func, max_retries, current_retry \\ 0) do
    func.()
  rescue
    e ->
      error_message = Exception.message(e)

      # Check if this is a rate limit error or server error
      is_retryable =
        String.contains?(error_message, "rate limit") or
          String.contains?(error_message, "server error") or
          String.contains?(error_message, "too many requests")

      if is_retryable and current_retry < max_retries do
        # Exponential backoff: 2^n * 100ms + random jitter
        backoff_ms = :math.pow(2, current_retry) * 100 + :rand.uniform(100)
        Process.sleep(trunc(backoff_ms))
        call_with_retry(func, max_retries, current_retry + 1)
      else
        {:error, error_message}
      end
  end
end
