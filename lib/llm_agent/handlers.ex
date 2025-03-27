defmodule LLMAgent.Handlers do
  @moduledoc """
  Provides standard handlers for processing LLM-specific signals.

  This module implements signal handlers for the various LLM agent signal types,
  following AgentForge's handler pattern. Each handler takes a signal and state,
  processes the signal, and returns a tuple with a result and a new state.
  """

  require Logger

  alias LLMAgent.{Signals, Store}

  @doc """
  Handles user message signals.

  Takes a user message, adds it to history, and generates the appropriate next signal
  (thinking, tool call, or response) based on the message content and available tools.

  ## Parameters

  - `signal` - The user message signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.user_message("Hello")
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.message_handler(signal, state)
      iex> match?({:emit, %{type: :thinking}}, result) or match?({:emit, %{type: :response}}, result)
      true
  """
  def message_handler(%{type: :user_message} = signal, state) do
    Logger.info("Processing user message: #{inspect(signal.data)}")

    # Add user message to history
    new_state = Store.add_message(state, "user", signal.data)

    # Get LLM provider
    _llm_provider = Map.get(state, :llm_provider, :default)
    tools = Map.get(state, :available_tools, [])

    # Prepare LLM context from history
    history = Store.get_llm_history(new_state)

    # Call LLM with message and available tools
    llm_client = Map.get(state, :llm_client, &call_llm/3)

    case llm_client.(signal.data, history, tools) do
      {:thinking, thought} ->
        thinking_signal = Signals.thinking(thought, 1)
        updated_state = Store.add_thought(new_state, thought)

        {{:emit, thinking_signal}, updated_state}

      {:tool_call, tool, args} ->
        tool_signal = Signals.tool_call(tool, args)

        {{:emit, tool_signal}, new_state}

      {:response, content} ->
        response_signal = Signals.response(content)
        updated_state = Store.add_message(new_state, "assistant", content)

        {{:emit, response_signal}, updated_state}

      {:error, message} ->
        error_signal = Signals.error(message, "llm_call")

        {{:emit, error_signal}, new_state}
    end
  end

  def message_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles thinking step signals.

  Processes a thinking step, adds it to state, and determines the next action
  (continue thinking, call a tool, or generate a response).

  ## Parameters

  - `signal` - The thinking signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.thinking("I need stock data", 1)
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.thinking_handler(signal, state)
      iex> is_tuple(result) and is_map(new_state)
      true
  """
  def thinking_handler(%{type: :thinking} = signal, state) do
    Logger.info("Processing thinking step: #{inspect(signal.data)}")

    # Get current step and thought
    step = signal.meta.step
    thought = signal.data

    # Add thought to state if not already there
    new_state =
      if Enum.member?(Store.get_thoughts(state), thought) do
        state
      else
        Store.add_thought(state, thought)
      end

    # Call LLM with updated context including thoughts
    history = Store.get_llm_history(new_state)
    thoughts = Store.get_thoughts(new_state)
    _tools = Map.get(state, :available_tools, [])

    # Get LLM function from state or use default
    llm_with_thinking = Map.get(state, :llm_with_thinking, &call_llm_with_thinking/3)

    case llm_with_thinking.(history, thoughts, []) do
      {:thinking, next_thought} ->
        # Continue thinking
        next_signal = Signals.thinking(next_thought, step + 1)
        updated_state = Store.add_thought(new_state, next_thought)

        {{:emit, next_signal}, updated_state}

      {:tool_call, tool, args} ->
        # Need to call a tool
        tool_signal = Signals.tool_call(tool, args)
        {{:emit, tool_signal}, new_state}

      {:response, content} ->
        # Final response
        response_signal = Signals.response(content)
        final_state = Store.add_message(new_state, "assistant", content)

        {{:emit, response_signal}, final_state}

      {:error, message} ->
        error_signal = Signals.error(message, "thinking")
        {{:emit, error_signal}, new_state}
    end
  end

  def thinking_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles tool call signals.

  Executes the specified tool with the provided arguments and generates a tool result signal.
  Includes parameter validation based on tool schema and detailed error handling.

  ## Parameters

  - `signal` - The tool call signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.tool_call("get_weather", %{city: "New York"})
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.tool_handler(signal, state)
      iex> is_tuple(result) and is_map(new_state)
      true
  """
  def tool_handler(%{type: :tool_call} = signal, state) do
    tool_name = signal.data.name
    tool_args = signal.data.args

    Logger.info("Tool call: #{tool_name} with args: #{inspect(tool_args)}")

    # Get tool registry from state or use default
    tool_registry = Map.get(state, :tool_registry, &AgentForge.Tools.get/1)

    # Get tool from registry
    case tool_registry.(tool_name) do
      {:ok, %{execute: tool_fn, parameters: params_schema} = tool} ->
        # Validate parameters against schema if schema exists
        validation_result =
          if params_schema do
            validate_tool_parameters(tool_args, params_schema)
          else
            {:ok, tool_args}
          end

        case validation_result do
          {:ok, validated_args} ->
            # Execute tool with validated args
            try do
              # Track start time for performance metrics
              start_time = System.monotonic_time(:millisecond)

              # Execute tool function
              result = tool_fn.(validated_args)

              # Calculate execution time
              execution_time = System.monotonic_time(:millisecond) - start_time

              # Create tool result signal with execution metadata
              result_signal =
                Signals.tool_result(
                  tool_name,
                  result,
                  %{
                    execution_time_ms: execution_time,
                    tool_type: Map.get(tool, :type, "unknown")
                  }
                )

              # Update state with detailed tool call information
              new_state =
                state
                |> Store.add_tool_call(
                  tool_name,
                  validated_args,
                  %{
                    result: result,
                    execution_time_ms: execution_time,
                    status: "success",
                    timestamp: DateTime.utc_now()
                  }
                )
                |> Map.update(
                  :execution_stats,
                  %{tool_calls: 1, total_execution_time: execution_time},
                  fn stats ->
                    stats
                    |> Map.update(:tool_calls, 1, &(&1 + 1))
                    |> Map.update(:total_execution_time, execution_time, &(&1 + execution_time))
                  end
                )

              {{:emit, result_signal}, new_state}
            rescue
              e ->
                stack = __STACKTRACE__
                error_message = Exception.message(e)

                error_data = %{
                  message: error_message,
                  type: "execution_error",
                  stacktrace: Enum.take(stack, 3),
                  tool: tool_name,
                  args: validated_args
                }

                # Log detailed error for debugging
                Logger.error("Tool execution error: #{inspect(error_data)}")

                # Create error signal with context
                error_signal =
                  Signals.error(
                    error_message,
                    tool_name,
                    %{error_type: "execution_error", args: validated_args}
                  )

                # Update state with error information
                new_state =
                  Store.add_tool_call(
                    state,
                    tool_name,
                    validated_args,
                    %{
                      error: error_message,
                      status: "error",
                      error_type: "execution_error"
                    }
                  )

                {{:emit, error_signal}, new_state}
            end

          {:error, validation_errors} ->
            # Parameter validation failed
            error_message = "Invalid tool parameters: #{inspect(validation_errors)}"
            Logger.warning(error_message)

            # Create detailed error signal
            error_signal =
              Signals.error(
                error_message,
                tool_name,
                %{
                  error_type: "validation_error",
                  args: tool_args,
                  validation_errors: validation_errors,
                  expected_schema: params_schema
                }
              )

            # Update state with validation error
            new_state =
              Store.add_tool_call(
                state,
                tool_name,
                tool_args,
                %{
                  error: error_message,
                  status: "error",
                  error_type: "validation_error",
                  validation_errors: validation_errors
                }
              )

            {{:emit, error_signal}, new_state}
        end

      {:ok, tool_fn} when is_function(tool_fn) ->
        # Simple tool without schema, execute directly
        try do
          result = tool_fn.(tool_args)
          result_signal = Signals.tool_result(tool_name, result)
          new_state = Store.add_tool_call(state, tool_name, tool_args, result)

          {{:emit, result_signal}, new_state}
        rescue
          e ->
            error_message = Exception.message(e)
            error_signal = Signals.error(error_message, tool_name)

            # Update state with error
            new_state =
              Store.add_tool_call(
                state,
                tool_name,
                tool_args,
                %{
                  error: error_message,
                  status: "error"
                }
              )

            {{:emit, error_signal}, new_state}
        end

      {:error, reason} ->
        # Tool not found in registry
        error_message = "Tool not found: #{reason}"
        Logger.warning(error_message)

        error_signal =
          Signals.error(
            error_message,
            tool_name,
            %{error_type: "not_found", available_tools: list_available_tools(state)}
          )

        # Update state with not found error
        new_state =
          Store.add_tool_call(
            state,
            tool_name,
            tool_args,
            %{
              error: error_message,
              status: "error",
              error_type: "not_found"
            }
          )

        {{:emit, error_signal}, new_state}
    end
  end

  def tool_handler(_signal, state), do: {:skip, state}

  # Helper function to validate tool parameters against schema
  defp validate_tool_parameters(args, schema) do
    # Implementation of JSON Schema validation
    # This is a simplified version, in production would use a proper validator
    try do
      # Check required fields
      required = Map.get(schema, "required", [])
      missing_fields = Enum.filter(required, fn field -> is_nil(Map.get(args, field)) end)

      if length(missing_fields) > 0 do
        {:error, %{missing_required: missing_fields}}
      else
        # Validate types if properties defined
        properties = Map.get(schema, "properties", %{})

        validation_errors =
          Enum.reduce(properties, %{}, fn {field, field_schema}, errors ->
            value = Map.get(args, field)

            if is_nil(value) do
              # Skip validation for optional fields that are not provided
              errors
            else
              # Validate field type
              expected_type = Map.get(field_schema, "type")
              actual_type = determine_json_type(value)

              if expected_type != actual_type do
                Map.put(errors, field, "expected #{expected_type}, got #{actual_type}")
              else
                errors
              end
            end
          end)

        if map_size(validation_errors) > 0 do
          {:error, %{type_mismatch: validation_errors}}
        else
          {:ok, args}
        end
      end
    rescue
      e -> {:error, %{validation_error: Exception.message(e)}}
    end
  end

  # Helper to determine JSON Schema type of a value
  defp determine_json_type(value) when is_binary(value), do: "string"
  defp determine_json_type(value) when is_integer(value), do: "integer"
  defp determine_json_type(value) when is_float(value), do: "number"
  defp determine_json_type(value) when is_boolean(value), do: "boolean"
  defp determine_json_type(value) when is_nil(value), do: "null"
  defp determine_json_type(value) when is_map(value), do: "object"
  defp determine_json_type(value) when is_list(value), do: "array"

  # Get list of available tools from state
  defp list_available_tools(state) do
    available_tools = Map.get(state, :available_tools, [])

    Enum.map(available_tools, fn tool ->
      case tool do
        %{name: name} -> name
        name when is_binary(name) -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Handles tool result signals.

  Processes the result of a tool execution and generates the next signal based on the result.

  ## Parameters

  - `signal` - The tool result signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.tool_result("get_weather", %{temp: 72})
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.tool_result_handler(signal, state)
      iex> is_tuple(result) and is_map(new_state)
      true
  """
  def tool_result_handler(%{type: :tool_result} = signal, state) do
    Logger.info("Processing tool result: #{inspect(signal.data)}")

    # Get tool result
    tool_name = signal.data.name
    tool_result = signal.data.result

    # Get LLM history and tools
    history = Store.get_llm_history(state)
    thoughts = Store.get_thoughts(state)
    _tools = Map.get(state, :available_tools, [])

    # Get LLM function from state or use default
    llm_with_tool_result = Map.get(state, :llm_with_tool_result, &call_llm_with_tool_result/4)

    # Call LLM with tool result
    case llm_with_tool_result.(history, thoughts, tool_name, tool_result) do
      {:thinking, thought} ->
        thinking_signal = Signals.thinking(thought, 1)
        new_state = Store.add_thought(state, thought)

        {{:emit, thinking_signal}, new_state}

      {:tool_call, tool, args} ->
        tool_signal = Signals.tool_call(tool, args)
        {{:emit, tool_signal}, state}

      {:response, content} ->
        response_signal = Signals.response(content)
        new_state = Store.add_message(state, "assistant", content)

        {{:emit, response_signal}, new_state}

      {:error, message} ->
        error_signal = Signals.error(message, "tool_result")
        {{:emit, error_signal}, state}
    end
  end

  def tool_result_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles task state signals.

  Updates the state of a task and generates a notification if necessary.

  ## Parameters

  - `signal` - The task state signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.task_state("task_123", "completed")
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.task_handler(signal, state)
      iex> is_tuple(result) and is_map(new_state)
      true
  """
  def task_handler(%{type: :task_state} = signal, state) do
    task_id = signal.data.task_id
    task_state = signal.data.state

    # Update task in state
    new_state = Store.update_task_state(state, task_id, task_state)

    # Return the updated state without emitting a new signal
    {:skip, new_state}
  end

  def task_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles response signals.

  Formats the final response and may trigger notifications or other side effects.

  ## Parameters

  - `signal` - The response signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.response("AAPL is trading at $200")
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.response_handler(signal, state)
      iex> is_tuple(result) and is_map(new_state)
      true
  """
  def response_handler(%{type: :response} = signal, state) do
    # Format response if a formatter is provided
    formatter = Map.get(state, :response_formatter)

    formatted_response =
      if is_function(formatter, 1) do
        formatter.(signal.data)
      else
        signal.data
      end

    # Create signal with formatted response
    formatted_signal = Signals.response(formatted_response)

    # Return formatted response with unchanged state
    # This is the final signal in the chain
    {{:halt, formatted_signal}, state}
  end

  def response_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles error signals.

  Processes errors and may implement recovery strategies.

  ## Parameters

  - `signal` - The error signal
  - `state` - The current store state

  ## Returns

  A tuple containing the result and updated state.

  ## Examples

      iex> signal = LLMAgent.Signals.error("API unavailable", "get_weather")
      iex> state = LLMAgent.Store.new()
      iex> {result, new_state} = LLMAgent.Handlers.error_handler(signal, state)
      iex> is_tuple(result) and is_map(new_state)
      true
  """
  def error_handler(%{type: :error} = signal, state) do
    message = signal.data.message
    source = signal.data.source

    # Log error
    _error_message = "LLMAgent error in #{source}: #{message}"
    Logger.error("LLMAgent error in #{source}: #{message}")

    # Attempt recovery based on source
    case source do
      "llm_call" ->
        # LLM service error - return error message as response
        response = "I'm sorry, I'm having trouble processing your request: #{message}"
        response_signal = Signals.response(response)

        new_state = Store.add_message(state, "assistant", response)
        {{:emit, response_signal}, new_state}

      "tool_call" ->
        # Tool error - return error message as response
        response = "I tried to use a tool but encountered an error: #{message}"
        response_signal = Signals.response(response)

        new_state = Store.add_message(state, "assistant", response)
        {{:emit, response_signal}, new_state}

      _ ->
        # Generic error - return as response
        response = "An error occurred: #{message}"
        response_signal = Signals.response(response)

        new_state = Store.add_message(state, "assistant", response)
        {{:emit, response_signal}, new_state}
    end
  end

  def error_handler(_signal, state), do: {:skip, state}

  # Private functions

  # Default LLM client implementation
  defp call_llm(_message, _history, _tools) do
    # This is a placeholder - in a real implementation, this would call an LLM service
    # In production, this would be replaced by a real LLM client injected into the state
    {:response, "This is a placeholder response. Implement a real LLM client."}
  end

  defp call_llm_with_thinking(_history, _thoughts, _tools) do
    # Placeholder - in a real implementation, this would call an LLM service
    {:response, "This is a placeholder response after thinking. Implement a real LLM client."}
  end

  defp call_llm_with_tool_result(_history, _thoughts, _tool_name, _tool_result) do
    # Mock implementation that returns a thinking signal
    {:thinking, "I've processed the tool result and am continuing to work on the task."}
  end
end
