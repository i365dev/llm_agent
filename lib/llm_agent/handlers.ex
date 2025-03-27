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

    # Get tool from AgentForge Tools registry
    case AgentForge.Tools.get(tool_name) do
      {:ok, tool_fn} ->
        # Execute tool
        try do
          result = tool_fn.(tool_args)

          # Create tool result signal
          result_signal = Signals.tool_result(tool_name, result)

          # Update state with tool call and result
          new_state = Store.add_tool_call(state, tool_name, tool_args, result)

          {{:emit, result_signal}, new_state}
        rescue
          e ->
            error_message = Exception.message(e)
            error_signal = Signals.error(error_message, tool_name)
            {{:emit, error_signal}, state}
        end

      {:error, reason} ->
        error_signal = Signals.error("Tool not found: #{reason}", tool_name)
        {{:emit, error_signal}, state}
    end
  end

  def tool_handler(_signal, state), do: {:skip, state}

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
