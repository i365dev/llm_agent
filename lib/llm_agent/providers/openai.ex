defmodule LLMAgent.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation for LLMAgent.

  This module implements the LLM provider interface for OpenAI, handling
  API calls, response parsing, and error handling specific to OpenAI's API.
  """

  require Logger

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
      stream = Map.get(params, :stream, false)

      # Format request body
      request_body =
        %{
          model: model,
          messages: format_messages(messages),
          temperature: Map.get(params, :temperature, 0.7),
          max_tokens: Map.get(params, :max_tokens),
          top_p: Map.get(params, :top_p, 1),
          frequency_penalty: Map.get(params, :frequency_penalty, 0),
          presence_penalty: Map.get(params, :presence_penalty, 0),
          stream: stream
        }
        |> remove_nil_values()

      # Add tools if provided
      request_body =
        if length(tools) > 0 do
          Map.merge(request_body, %{
            tools: format_tools(tools),
            tool_choice: Map.get(params, :tool_choice, "auto")
          })
        else
          request_body
        end

      # Add user identifier if provided
      request_body =
        if Map.has_key?(params, :user) do
          Map.put(request_body, :user, Map.get(params, :user))
        else
          request_body
        end

      # Configure request options
      request_options = [
        api_key: api_key,
        http_options: [
          recv_timeout: Map.get(params, :timeout, 60_000),
          ssl: [versions: [:"tlsv1.2"]]
        ]
      ]

      # Set organization if provided
      request_options =
        if Map.has_key?(params, :organization) do
          Keyword.put(request_options, :organization, Map.get(params, :organization))
        else
          request_options
        end

      # Log request (excluding sensitive data)
      Logger.debug(fn ->
        "OpenAI request: #{inspect(Map.drop(request_body, [:api_key]))}"
      end)

      # Make API call with retry logic
      api_call_result =
        make_openai_api_call(
          request_body,
          request_options,
          stream,
          params,
          max_retries,
          messages,
          tools
        )

      handle_openai_response(api_call_result, tools, params)
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
      dimensions = Map.get(params, :dimensions)

      # Format request body
      request_body =
        %{
          model: model,
          input: input
        }
        |> add_if_present(:dimensions, dimensions)
        |> remove_nil_values()

      # Configure request options
      request_options = [
        api_key: api_key,
        http_options: [
          recv_timeout: Map.get(params, :timeout, 60_000),
          ssl: [versions: [:"tlsv1.2"]]
        ]
      ]

      # Set organization if provided
      request_options =
        if Map.has_key?(params, :organization) do
          Keyword.put(request_options, :organization, Map.get(params, :organization))
        else
          request_options
        end

      # Make API call with retry logic
      api_call_result = make_embedding_api_call(request_body, request_options, max_retries)
      handle_embedding_response(api_call_result)
    end
  end

  # Handle OpenAI completion response
  defp handle_openai_response({:ok, response}, tools, _params) do
    # Process successful response
    parsed_response = parse_openai_response(response, tools)
    {:ok, parsed_response}
  end

  defp handle_openai_response({:error, %{status: status, body: body}}, _tools, params) do
    # Format API error response
    error_message = extract_error_message(body)
    retry_after = extract_retry_after(body)

    error = %{
      message: "OpenAI API error: #{error_message}",
      code: Map.get(body, "error", %{})["code"],
      type: Map.get(body, "error", %{})["type"],
      http_status: status,
      source: "openai_provider",
      retry_after: retry_after,
      context: %{status: status, body: body, request_params: sanitize_params(params)}
    }

    # Log error for debugging
    Logger.error("OpenAI API error: #{error_message} (Status: #{status})")

    {:error, error}
  end

  defp handle_openai_response({:error, reason}, _tools, params) do
    # Format other errors
    error_message =
      cond do
        is_binary(reason) -> reason
        is_map(reason) and Map.has_key?(reason, :message) -> reason.message
        true -> inspect(reason)
      end

    error = %{
      message: "OpenAI API error: #{error_message}",
      source: "openai_provider",
      context: %{reason: reason, request_params: sanitize_params(params)}
    }

    # Log error for debugging
    Logger.error("OpenAI API error: #{error_message}")

    {:error, error}
  end

  # Handle embedding response with consistent pattern
  defp handle_embedding_response({:ok, response}) do
    extract_embeddings(response)
  end

  defp handle_embedding_response({:error, %{status: status, body: body}}) do
    # Format HTTP error
    error_message = extract_error_message(body)
    retry_after = extract_retry_after(body)

    error = %{
      message: "OpenAI API error: #{error_message}",
      code: Map.get(body, "error", %{})["code"],
      type: Map.get(body, "error", %{})["type"],
      http_status: status,
      source: "openai_provider",
      retry_after: retry_after,
      context: %{status: status, body: body}
    }

    # Log error for debugging
    Logger.error("OpenAI embedding error: #{error_message} (Status: #{status})")

    {:error, error}
  end

  defp handle_embedding_response({:error, reason}) do
    # Format other errors
    error_message =
      cond do
        is_binary(reason) -> reason
        is_map(reason) and Map.has_key?(reason, :message) -> reason.message
        true -> inspect(reason)
      end

    error = %{
      message: "OpenAI embedding error: #{error_message}",
      source: "openai_provider",
      context: %{reason: reason}
    }

    # Log error for debugging
    Logger.error("OpenAI embedding error: #{error_message}")

    {:error, error}
  end

  # Extract error message from response body
  defp extract_error_message(body) when is_map(body) do
    error = Map.get(body, "error", %{})
    message = Map.get(error, "message", "Unknown error")

    if is_binary(message) and message != "" do
      message
    else
      inspect(error)
    end
  end

  defp extract_error_message(body) do
    inspect(body)
  end

  # Extract retry-after value from rate limit responses
  defp extract_retry_after(body) when is_map(body) do
    error = Map.get(body, "error", %{})

    if Map.get(error, "type") == "rate_limit_exceeded" do
      Map.get(error, "retry_after")
    else
      nil
    end
  end

  defp extract_retry_after(_), do: nil

  # Extract embeddings from response
  defp extract_embeddings(%{data: data}) when is_list(data) do
    # Extract embedding vectors from response
    embeddings = Enum.map(data, fn item -> Map.get(item, :embedding) end)
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

  # Default callback for streaming responses
  defp stream_default_callback(chunk) do
    # Just log the chunk by default
    Logger.debug("Received stream chunk: #{inspect(chunk)}")
  end

  # Remove sensitive data from logs
  defp sanitize_params(params) do
    params
    |> Map.drop([:api_key])
  end

  # Add value to map if present and not nil
  defp add_if_present(map, _key, nil), do: map
  defp add_if_present(map, key, value), do: Map.put(map, key, value)

  # Remove nil values from map
  defp remove_nil_values(map) do
    map
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
    |> Map.new()
  end

  # API call helper functions

  defp make_openai_api_call(
         request_body,
         request_options,
         stream,
         params,
         max_retries,
         messages,
         tools
       ) do
    if Code.ensure_loaded?(OpenAI) do
      # Use actual OpenAI API if available
      call_with_retry(
        fn -> execute_openai_call(request_body, request_options, stream, params) end,
        max_retries
      )
    else
      # Fall back to mock if OpenAI module not available
      Logger.warning("OpenAI module not available, using mock responses")
      mock_openai_response(messages, tools, params)
    end
  end

  defp execute_openai_call(request_body, request_options, stream, params) do
    if stream do
      OpenAI.chat_completion(
        request_body,
        request_options ++
          [
            stream_options: [
              callback: Map.get(params, :stream_callback, &stream_default_callback/1)
            ]
          ]
      )
    else
      OpenAI.chat_completion(request_body, request_options)
    end
  end

  defp make_embedding_api_call(request_body, request_options, max_retries) do
    if Code.ensure_loaded?(OpenAI) do
      # Use actual OpenAI API if available
      call_with_retry(
        fn -> OpenAI.embeddings(request_body, request_options) end,
        max_retries
      )
    else
      # Fall back to mock if OpenAI module not available
      Logger.warning("OpenAI module not available, using mock responses")
      mock_openai_embedding_response(request_body)
    end
  end

  # Private functions for message and tool formatting

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

  defp parse_openai_response(response, tools) do
    # Extract the relevant parts of the OpenAI response
    case response do
      %{choices: choices} when is_list(choices) and length(choices) > 0 ->
        choice = List.first(choices)
        parse_choice(choice, tools)

      %{choices: []} ->
        %{content: nil, tool_calls: []}

      _ ->
        %{content: inspect(response), tool_calls: []}
    end
  end

  # Parse individual choice from response
  defp parse_choice(choice, tools) do
    message = choice.message
    tool_calls = Map.get(message, :tool_calls, [])

    # Create base response structure
    base_response = %{
      content: Map.get(message, :content),
      role: Map.get(message, :role, "assistant")
    }

    # Check if tool calls exist and are non-empty
    if is_list(tool_calls) and length(tool_calls) > 0 do
      # Add parsed tool calls to response
      parsed_tool_calls = parse_tool_calls(tool_calls, tools)
      Map.put(base_response, :tool_calls, parsed_tool_calls)
    else
      # Just add empty tool calls list
      Map.put(base_response, :tool_calls, [])
    end
  end

  # Parse tool calls from response
  defp parse_tool_calls(tool_calls, _tools) do
    Enum.map(tool_calls, fn call ->
      function = Map.get(call, :function, %{})

      # Parse JSON arguments
      args =
        case Jason.decode(Map.get(function, :arguments, "{}")) do
          {:ok, parsed} -> parsed
          _ -> %{}
        end

      %{
        id: Map.get(call, :id, ""),
        name: Map.get(function, :name, ""),
        args: args
      }
    end)
  end

  # Retry mechanism for API calls
  defp call_with_retry(api_call, max_retries, current_retry \\ 0, backoff_ms \\ 1000) do
    api_call.()
  rescue
    e ->
      if current_retry < max_retries do
        # Exponential backoff with jitter
        jitter = :rand.uniform(div(backoff_ms, 4))
        wait_time = backoff_ms + jitter

        Logger.warning(
          "API call failed, retrying (#{current_retry + 1}/#{max_retries}) after #{wait_time}ms: #{Exception.message(e)}"
        )

        :timer.sleep(wait_time)
        call_with_retry(api_call, max_retries, current_retry + 1, backoff_ms * 2)
      else
        Logger.error("API call failed after #{max_retries} retries: #{Exception.message(e)}")
        {:error, %{message: Exception.message(e), exception: e}}
      end
  end

  # Mock responses for testing and development

  defp mock_openai_response(messages, tools, params) do
    # Create a deterministic but varied mock response based on input
    last_message =
      messages
      |> Enum.reverse()
      |> Enum.find(fn
        %{role: "user"} -> true
        %{"role" => "user"} -> true
        _ -> false
      end)

    content =
      case last_message do
        %{content: content} -> content
        %{"content" => content} -> content
        _ -> ""
      end

    mock_based_on_content(content, tools, params)
  end

  defp mock_based_on_content(content, tools, params) do
    cond do
      # Mock tool call response
      has_tool_keywords?(content) and has_matching_tool?(content, tools) ->
        tool_name = find_matching_tool_name(content, tools)

        {:ok,
         %{
           choices: [
             %{
               message: %{
                 role: "assistant",
                 content: nil,
                 tool_calls: [
                   %{
                     id: "mock_call_#{:rand.uniform(1000)}",
                     function: %{
                       name: tool_name,
                       arguments: generate_mock_args(tool_name, content)
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # Mock streaming response
      Map.get(params, :stream, false) ->
        {:ok,
         %{
           choices: [
             %{
               message: %{
                 role: "assistant",
                 content: "This is a mock streaming response for: #{content}",
                 tool_calls: []
               }
             }
           ]
         }}

      # Mock regular response
      true ->
        {:ok,
         %{
           choices: [
             %{
               message: %{
                 role: "assistant",
                 content: "This is a mock response for: #{content}",
                 tool_calls: []
               }
             }
           ]
         }}
    end
  end

  defp has_tool_keywords?(content) do
    tool_keywords = ["get", "find", "search", "calculate", "analyze", "create", "fetch"]
    Enum.any?(tool_keywords, &String.contains?(String.downcase(content), &1))
  end

  defp has_matching_tool?(content, tools) do
    Enum.any?(tools, fn tool ->
      name = get_tool_name(tool)
      String.contains?(String.downcase(content), String.downcase(name))
    end)
  end

  defp find_matching_tool_name(content, tools) do
    Enum.find_value(tools, "unknown_tool", fn tool ->
      name = get_tool_name(tool)

      if String.contains?(String.downcase(content), String.downcase(name)) do
        name
      else
        nil
      end
    end)
  end

  defp generate_mock_args(tool_name, content) do
    case tool_name do
      "get_weather" ->
        ~s({"location":"New York"})

      "search_web" ->
        ~s({"query":"#{String.slice(content, 0, 50)}"})

      "get_stock_price" ->
        ~s({"ticker":"AAPL"})

      _ ->
        ~s({"query":"#{String.slice(content, 0, 30)}"})
    end
  end

  defp mock_openai_embedding_response(params) do
    # Generate mock embeddings of the right dimensionality
    input = Map.get(params, :input)
    dimensions = Map.get(params, :dimensions, 1536)

    embeddings =
      case input do
        input when is_binary(input) ->
          [generate_mock_embedding(input, dimensions)]

        input when is_list(input) ->
          Enum.map(input, &generate_mock_embedding(&1, dimensions))

        _ ->
          [generate_mock_embedding("", dimensions)]
      end

    {:ok,
     %{
       data:
         Enum.map(embeddings, fn embedding ->
           %{
             embedding: embedding,
             index: 0,
             object: "embedding"
           }
         end)
     }}
  end

  defp generate_mock_embedding(input, dimensions) do
    # Create a deterministic but varied mock embedding
    seed = :erlang.phash2(input)
    :rand.seed(:exsss, {seed, seed, seed})

    for _i <- 1..dimensions do
      :rand.uniform() - 0.5
    end
  end
end
