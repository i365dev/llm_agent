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

    # Get provider and tools configuration
    provider = Map.get(state, :provider, :openai)
    tools = Map.get(state, :available_tools, [])

    # Prepare LLM context from history
    history = Store.get_llm_history(new_state)

    # Use LLMAgent.Plugin to call the LLM directly for consistency
    try do
      llm_result =
        LLMAgent.Plugin.call_llm(%{
          "provider" => provider,
          "messages" => history,
          "tools" => tools,
          "options" => Map.get(state, :llm_options, %{})
        })

      # Process the result based on content and tool calls
      cond do
        # If there are tool calls in the response
        has_tool_calls?(llm_result) ->
          tool_calls = extract_tool_calls(llm_result)
          # Use first tool call (could be extended to handle multiple)
          [first_tool | _rest] = tool_calls

          tool_data = %{
            name: first_tool.name,
            args: first_tool.arguments
          }

          # Use AgentForge.Signal directly instead of Signals module
          {AgentForge.Signal.emit(:tool_call, tool_data), new_state}

        # If we should start thinking (based on content patterns)
        contains_thinking_marker?(llm_result) ->
          thought = extract_content(llm_result)
          updated_state = Store.add_thought(new_state, thought)
          # Start thinking process at step 1
          thinking_meta = %{step: 1}
          {AgentForge.Signal.emit(:thinking, thought, thinking_meta), updated_state}

        # Otherwise, generate a direct response
        true ->
          content = extract_content(llm_result)
          updated_state = Store.add_message(new_state, "assistant", content)
          {AgentForge.Signal.emit(:response, content), updated_state}
      end
    rescue
      error ->
        Logger.error("Error in message handler: #{inspect(error)}")
        error_meta = %{source: "llm_call"}

        {AgentForge.Signal.emit(:error, "LLM processing failed: #{inspect(error)}", error_meta),
         new_state}
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
    tools = Map.get(state, :available_tools, [])
    provider = Map.get(state, :provider, :openai)

    # Use LLMAgent.Plugin to call the LLM directly - this ensures we're using
    # the real implementation rather than a mock function
    try do
      llm_result =
        LLMAgent.Plugin.call_llm(%{
          "provider" => provider,
          "messages" => format_history_with_thought(history, thought),
          "tools" => tools,
          "options" => Map.get(state, :llm_options, %{})
        })

      # Process the result based on content and tool calls
      cond do
        # If there are tool calls in the response
        has_tool_calls?(llm_result) ->
          tool_calls = extract_tool_calls(llm_result)
          # Use first tool call (could be extended to handle multiple)
          [first_tool | _rest] = tool_calls

          tool_data = %{
            name: first_tool.name,
            args: first_tool.arguments
          }

          # Use AgentForge.Signal directly instead of Signals module
          {AgentForge.Signal.emit(:tool_call, tool_data), new_state}

        # If we want to continue thinking (based on content containing a thinking marker)
        should_continue_thinking?(llm_result, step) ->
          next_thought = extract_content(llm_result)
          updated_state = Store.add_thought(new_state, next_thought)
          next_meta = %{step: step + 1}
          {AgentForge.Signal.emit(:thinking, next_thought, next_meta), updated_state}

        # Otherwise, generate a response
        true ->
          content = extract_content(llm_result)
          final_state = Store.add_message(new_state, "assistant", content)
          {AgentForge.Signal.emit(:response, content), final_state}
      end
    rescue
      error ->
        Logger.error("Error in thinking handler: #{inspect(error)}")
        error_meta = %{source: "thinking"}

        {AgentForge.Signal.emit(:error, "LLM processing failed: #{inspect(error)}", error_meta),
         state}
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
    with {:ok, _} <- validate_required_fields(args, schema),
         {:ok, _} <- validate_field_types(args, schema) do
      {:ok, args}
    end
  rescue
    e -> {:error, %{validation_error: Exception.message(e)}}
  end

  # Validate that all required fields are present
  defp validate_required_fields(args, schema) do
    required = Map.get(schema, "required", [])
    missing_fields = Enum.filter(required, fn field -> is_nil(Map.get(args, field)) end)

    if length(missing_fields) > 0 do
      {:error, %{missing_required: missing_fields}}
    else
      {:ok, args}
    end
  end

  # Validate field types against schema
  defp validate_field_types(args, schema) do
    properties = Map.get(schema, "properties", %{})
    validation_errors = check_field_types(args, properties)

    if map_size(validation_errors) > 0 do
      {:error, %{type_mismatch: validation_errors}}
    else
      {:ok, args}
    end
  end

  # Helper to check types of all fields
  defp check_field_types(args, properties) do
    Enum.reduce(properties, %{}, fn {field, field_schema}, errors ->
      value = Map.get(args, field)

      if is_nil(value) do
        # Skip validation for optional fields that are not provided
        errors
      else
        validate_field_type(field, field_schema, value, errors)
      end
    end)
  end

  # Validate individual field type
  defp validate_field_type(field, field_schema, value, errors) do
    expected_type = Map.get(field_schema, "type")
    actual_type = determine_json_type(value)

    if expected_type != actual_type do
      Map.put(errors, field, "expected #{expected_type}, got #{actual_type}")
    else
      errors
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
    _thoughts = Store.get_thoughts(state)
    tools = Map.get(state, :available_tools, [])

    # Update state to remove from pending tools if applicable
    new_state =
      state
      |> Map.update(:pending_tools, [], fn pending ->
        Enum.reject(pending, fn %{name: name} -> name == tool_name end)
      end)

    # Add function call to history for proper LLM context
    new_state =
      Store.add_function_result(new_state, tool_name, tool_result)

    # Use LLMAgent.Plugin to call the LLM directly
    try do
      provider = Map.get(state, :provider, :openai)

      # Format history to include tool result
      formatted_history = format_history_with_tool_result(history, tool_name, tool_result)

      llm_result =
        LLMAgent.Plugin.call_llm(%{
          "provider" => provider,
          "messages" => formatted_history,
          "tools" => tools,
          "options" => Map.get(state, :llm_options, %{})
        })

      # Process the result based on content and tool calls
      cond do
        # If there are tool calls in the response
        has_tool_calls?(llm_result) ->
          tool_calls = extract_tool_calls(llm_result)
          # Use first tool call
          [first_tool | _rest] = tool_calls

          tool_data = %{
            name: first_tool.name,
            args: first_tool.arguments
          }

          # Use AgentForge.Signal directly
          {AgentForge.Signal.emit(:tool_call, tool_data), new_state}

        # If we should continue thinking
        should_continue_thinking?(llm_result, 1) ->
          next_thought = extract_content(llm_result)
          updated_state = Store.add_thought(new_state, next_thought)
          # Start from step 2 after tool use
          next_meta = %{step: 2}
          {AgentForge.Signal.emit(:thinking, next_thought, next_meta), updated_state}

        # Otherwise, generate a response
        true ->
          content = extract_content(llm_result)
          final_state = Store.add_message(new_state, "assistant", content)
          {AgentForge.Signal.emit(:response, content), final_state}
      end
    rescue
      error ->
        Logger.error("Error in tool result handler: #{inspect(error)}")
        error_meta = %{source: "tool_result", tool: tool_name}

        {AgentForge.Signal.emit(:error, "LLM processing failed: #{inspect(error)}", error_meta),
         state}
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

    # Use AgentForge.Signal directly to create formatted response signal
    # and return as halting signal to end the flow
    formatted_signal = AgentForge.Signal.new(:response, formatted_response)

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

    # Log error with more context
    Logger.error("LLMAgent error in #{source}: #{message}\nSignal: #{inspect(signal)}")

    # Attempt recovery based on source
    case source do
      "llm_call" ->
        # LLM service error - return error message as response
        response = "I'm sorry, I'm having trouble processing your request: #{message}"

        # Create error log in state for debugging
        updated_state =
          state
          |> Store.add_error({:llm_error, message, DateTime.utc_now()})
          |> Store.add_message("assistant", response)

        # Use AgentForge.Signal directly
        {AgentForge.Signal.emit(:response, response), updated_state}

      "tool_call" ->
        # Tool error - return error message as response
        response = "I tried to use a tool but encountered an error: #{message}"

        # Add more context to state for debugging
        updated_state =
          state
          |> Store.add_error({:tool_error, message, DateTime.utc_now()})
          |> Store.add_message("assistant", response)

        # Use AgentForge.Signal directly
        {AgentForge.Signal.emit(:response, response), updated_state}

      "tool_result" ->
        # Error processing tool result
        response = "I received a tool result but encountered an error: #{message}"

        updated_state =
          state
          |> Store.add_error({:tool_result_error, message, DateTime.utc_now()})
          |> Store.add_message("assistant", response)

        # Use AgentForge.Signal directly
        {AgentForge.Signal.emit(:response, response), updated_state}

      _ ->
        # Generic error - return as response
        response = "An error occurred: #{message}"

        updated_state =
          state
          |> Store.add_error({:generic_error, message, DateTime.utc_now()})
          |> Store.add_message("assistant", response)

        # Use AgentForge.Signal directly
        {AgentForge.Signal.emit(:response, response), updated_state}
    end
  end

  def error_handler(_signal, state), do: {:skip, state}

  # Private functions

  # Helper functions for LLM processing with AgentForge integration

  # Format history with the current thought for LLM context
  defp format_history_with_thought(history, thought) do
    # Add a system message explaining the thought process
    thought_message = %{"role" => "system", "content" => "Current thinking step: #{thought}"}
    history ++ [thought_message]
  end

  # Format history with tool result for LLM context
  defp format_history_with_tool_result(history, tool_name, tool_result) do
    # Add a function result message to the conversation history
    formatted_result = Jason.encode!(tool_result, pretty: true)

    function_result_message = %{
      "role" => "function",
      "name" => tool_name,
      "content" => formatted_result
    }

    # Add system guidance message
    guidance_message = %{
      "role" => "system",
      "content" =>
        "You received a result from the #{tool_name} function. Use this information to continue the conversation."
    }

    history ++ [function_result_message, guidance_message]
  end

  # Check if an LLM response contains tool calls
  defp has_tool_calls?(llm_result) do
    case llm_result do
      %{"tool_calls" => tool_calls} when is_list(tool_calls) and length(tool_calls) > 0 -> true
      _ -> false
    end
  end

  # Check if content contains thinking markers that suggest this should be a thinking step
  defp contains_thinking_marker?(llm_result) do
    content = extract_content(llm_result)

    cond do
      is_nil(content) -> false
      String.contains?(content, "I need to think") -> true
      String.contains?(content, "Let me think") -> true
      String.contains?(content, "Thinking:") -> true
      String.match?(content, ~r/^Step \d+:/i) -> true
      String.match?(content, ~r/^Thinking step \d+:/i) -> true
      true -> false
    end
  end

  # Check if LLM response suggests continuation of a thinking process
  defp should_continue_thinking?(llm_result, current_step) do
    content = extract_content(llm_result)

    if is_nil(content) do
      false
    else
      contains_thinking_phrases?(content) or
        matches_step_pattern?(content, current_step) or
        numbered_list_thinking?(content) or
        starts_with_continuation_phrase?(content)
    end
  end

  # Check for explicit phrases indicating continued thinking
  defp contains_thinking_phrases?(content) do
    String.contains?(content, "I need to continue thinking") or
      String.contains?(content, "Let me continue")
  end

  # Check for patterns that indicate a new step in thinking
  defp matches_step_pattern?(content, current_step) do
    String.match?(content, ~r/^Step #{current_step + 1}:/i) or
      String.match?(content, ~r/^Thinking step #{current_step + 1}:/i)
  end

  # Check if content looks like a numbered list but not a final answer
  defp numbered_list_thinking?(content) do
    String.match?(content, ~r/^\d+\. /) and not String.contains?(content, "final answer")
  end

  # Check if content starts with phrases suggesting continuation
  defp starts_with_continuation_phrase?(content) do
    String.match?(content, ~r/^Next, I/i) or
      String.match?(content, ~r/^Now I need to/i)
  end

  # Extract content from an LLM response
  defp extract_content(llm_result) do
    case llm_result do
      %{"content" => content} when is_binary(content) ->
        content

      %{"message" => %{"content" => content}} when is_binary(content) ->
        content

      %{"choices" => [%{"message" => %{"content" => content}} | _]} when is_binary(content) ->
        content

      %{"choices" => [%{"text" => content} | _]} when is_binary(content) ->
        content

      # For OpenAI-specific format
      %{"choices" => [first | _]} ->
        get_in(first, ["message", "content"]) || ""

      # Fallback
      _ ->
        ""
    end
  end

  # Extract tool calls from an LLM response
  defp extract_tool_calls(llm_result) do
    case llm_result do
      # Standard format with direct tool_calls
      %{"tool_calls" => tool_calls} when is_list(tool_calls) ->
        parse_tool_calls(tool_calls)

      # OpenAI-specific format with choices
      %{"choices" => [%{"message" => %{"tool_calls" => tool_calls}} | _]} when is_list(tool_calls) ->
        parse_tool_calls(tool_calls)

      # No tool calls found
      _ ->
        []
    end
  end

  # Parse a list of tool calls into a standardized format
  defp parse_tool_calls(tool_calls) do
    Enum.map(tool_calls, &parse_single_tool_call/1)
  end

  # Parse a single tool call into a standardized format
  defp parse_single_tool_call(tool_call) do
    args_json = get_in(tool_call, ["function", "arguments"]) || "{}"
    name = get_in(tool_call, ["function", "name"]) || ""

    %{
      name: name,
      arguments: parse_arguments(args_json)
    }
  end

  # Parse arguments from JSON string
  defp parse_arguments(args_json) do
    case Jason.decode(args_json) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end
end
