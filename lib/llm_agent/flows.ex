defmodule LLMAgent.Flows do
  @moduledoc """
  Provides standard flow definitions for common LLM agent patterns.

  This module creates AgentForge flow compositions for different LLM agent use cases,
  such as conversational agents and task-based agents. It registers tools, creates
  appropriate handlers, and configures initial state.
  """

  alias AgentForge
  alias LLMAgent.{Handlers, Signals}

  @doc """
  Creates a standard conversation flow with the given system prompt and tools.

  ## Parameters

  - `system_prompt` - The system prompt that defines the agent's behavior
  - `tools` - A list of tools that the agent can use
  - `options` - Additional options for configuring the agent

  ## Returns

  A tuple containing the flow and initial state for the agent.

  ## Examples

      iex> {flow, state} = LLMAgent.Flows.conversation("You are a helpful assistant.", [])
      iex> is_function(flow) and is_map(state)
      true
  """
  def conversation(system_prompt, tools \\ [], options \\ []) do
    # Create initial state with system prompt in history
    initial_state = %{
      history: [%{role: "system", content: system_prompt}],
      available_tools: tools,
      thoughts: [],
      tool_calls: [],
      current_tasks: [],
      preferences: %{}
    }

    # Add any custom options to state
    initial_state = Map.merge(initial_state, Map.new(options))

    # Register tools with the system
    register_tools(tools)

    # Create flow with standard handlers
    flow = fn signal, state ->
      state
      |> handle_with(&Handlers.message_handler/2, signal)
      |> handle_with(&Handlers.thinking_handler/2, signal)
      |> handle_with(&Handlers.tool_handler/2, signal)
      |> handle_with(&Handlers.tool_result_handler/2, signal)
      |> handle_with(&Handlers.task_handler/2, signal)
      |> handle_with(&Handlers.response_handler/2, signal)
      |> handle_with(&Handlers.error_handler/2, signal)
    end

    {flow, initial_state}
  end

  @doc """
  Creates a task flow with the given task definition.

  A task flow executes a series of primitive operations defined in the task definition.

  ## Parameters

  - `task_definition` - The task definition as a list of AgentForge primitives
  - `options` - Additional options for the task flow

  ## Returns

  A function that can be used as a flow.

  ## Examples

      iex> task_def = [
      ...>   fn data -> Map.put(data, :step1, true) end
      ...> ]
      iex> flow = LLMAgent.Flows.task_flow(task_def)
      iex> is_function(flow)
      true
  """
  def task_flow(task_definition, options \\ []) do
    # Extract options
    _task_timeout = Keyword.get(options, :task_timeout, 60_000)

    # Create flow
    fn signal, state ->
      # Use primitive handler to execute task primitives
      state_with_primitives = Map.put(state, :primitives, task_definition)

      # Execute primitives
      try do
        # Execute each primitive in sequence
        {result, new_state} =
          Enum.reduce(task_definition, {signal, state_with_primitives}, fn primitive,
                                                                           {_signal,
                                                                            current_state} ->
            # Execute the primitive with the current signal and state
            case primitive.(current_state) do
              {:ok, result, updated_state} ->
                {result, updated_state}

              {:error, reason} ->
                throw({:error, reason})
            end
          end)

        {{:emit, result}, Map.drop(new_state, [:primitives])}
      catch
        {:error, reason} ->
          {{:emit, Signals.error(reason, "task_execution")}, state}
      end
    end
  end

  @doc """
  Creates a batch processing flow.

  A batch processing flow iterates over a collection of items and applies
  the batch handler to each item.

  ## Parameters

  - `items` - The collection of items to process
  - `batch_handler` - The handler function to apply to each item
  - `options` - Additional options for batch processing

  ## Returns

  A function that can be used as a flow.

  ## Examples

      iex> items = [1, 2, 3]
      iex> handler = fn signal, state -> {{:emit, signal}, state} end
      iex> flow = LLMAgent.Flows.batch_processing(items, handler)
      iex> is_function(flow)
      true
  """
  def batch_processing(items, batch_handler, _options \\ []) do
    # Create a flow
    fn signal, state ->
      # Initialize batch state
      batch = Map.get(state, :batch, %{items: items, index: 0})

      # Check if processing is complete
      if batch.index >= length(batch.items) do
        {{:halt, signal}, state}
      else
        # Get current item
        current_item = Enum.at(batch.items, batch.index)

        # Apply batch handler to current item
        state_with_item = Map.put(state, :current_item, current_item)
        {signal_result, new_state} = batch_handler.(signal, state_with_item)

        # Update batch state for next item
        updated_batch = %{batch | index: batch.index + 1}

        final_state =
          new_state
          |> Map.put(:batch, updated_batch)
          |> Map.delete(:current_item)

        {signal_result, final_state}
      end
    end
    |> with_middleware(fn signal, state, continue ->
      {result, new_state} = continue.(signal, state)
      {result, Map.put(new_state, :batch_processed, true)}
    end)
    |> map_flow(fn {result, state} ->
      {result, Map.put(state, :batch_processing_complete, true)}
    end)
  end

  @doc """
  Maps a flow to a new flow by applying a transformation function.

  Useful for creating derived flows that modify signal or state handling.

  ## Parameters

  - `flow` - The original flow
  - `transform_fn` - A function that transforms the flow's result

  ## Returns

  A new flow that applies the transformation.

  ## Examples

      iex> original_flow = fn signal, state -> {{:emit, signal}, state} end
      iex> transform = fn {result, state} -> {result, Map.put(state, :transformed, true)} end
      iex> new_flow = LLMAgent.Flows.map_flow(original_flow, transform)
      iex> is_function(new_flow)
      true
  """
  def map_flow(flow, transform_fn) do
    fn signal, state ->
      # Execute the original flow
      {signal_result, new_state} = flow.(signal, state)

      # Apply transformation
      transform_fn.({signal_result, new_state})
    end
  end

  @doc """
  Adds middleware to a flow.

  Middleware functions are executed before and after the main flow,
  allowing for consistent pre- and post-processing.

  ## Parameters

  - `flow` - The original flow
  - `middleware` - A function that receives the signal, state, and a continuation

  ## Returns

  A new flow with the middleware applied.

  ## Examples

      iex> flow = fn signal, state -> {{:emit, signal}, state} end
      iex> middleware = fn signal, state, continue ->
      ...>   {result, new_state} = continue.(signal, state)
      ...>   {result, Map.put(new_state, :middleware_applied, true)}
      ...> end
      iex> new_flow = LLMAgent.Flows.with_middleware(flow, middleware)
      iex> is_function(new_flow)
      true
  """
  def with_middleware(flow, middleware) do
    fn signal, state ->
      middleware.(signal, state, flow)
    end
  end

  @doc """
  Creates a flow for a simple question-answering agent.

  This is a specialized flow for handling basic question-answering without tools,
  providing a streamlined implementation for simple use cases.

  ## Parameters

  - `system_prompt` - The system prompt that defines the agent's behavior
  - `options` - Additional options for configuring the agent

  ## Returns

  A tuple containing the flow and initial state for the agent.

  ## Examples

      iex> {flow, state} = LLMAgent.Flows.qa_agent("You are a helpful assistant.")
      iex> is_function(flow) and is_map(state)
      true
  """
  def qa_agent(system_prompt, options \\ []) do
    # Create base conversation flow without any tools
    conversation(system_prompt, [], options)
  end

  @doc """
  Creates a flow for a tool-using agent.

  ## Parameters

  - `system_prompt` - The system prompt that defines the agent's behavior
  - `tools` - A list of tools that the agent can use
  - `options` - Additional options for configuring the agent

  ## Returns

  A tuple containing the flow and initial state for the agent.

  ## Examples

      iex> tools = [
      ...>   %{name: "get_time", description: "Get the current time", execute: fn _ -> %{time: DateTime.utc_now()} end}
      ...> ]
      iex> {flow, state} = LLMAgent.Flows.tool_agent("You are a helpful assistant that can use tools.", tools)
      iex> is_function(flow) and is_map(state)
      true
  """
  def tool_agent(system_prompt, tools, options \\ []) do
    # Create a more complex agent with tools
    conversation(system_prompt, tools, options)
  end

  # Private functions

  defp register_tools(tools) do
    # Register each tool with the system
    Enum.each(tools, fn tool ->
      AgentForge.Tools.register(tool.name, fn args ->
        # Execute the tool function
        try do
          tool.execute.(args)
        rescue
          e -> {:error, Exception.message(e)}
        end
      end)
    end)
  end

  # Helper function to handle signals with a handler
  defp handle_with({:halt, _} = result, _handler, _signal), do: result

  defp handle_with({:skip, state}, handler, signal) do
    case handler.(signal, state) do
      {:skip, new_state} -> {:skip, new_state}
      {:emit, new_signal} -> handle_with({:emit, new_signal}, handler, new_signal)
      {:halt, result} -> {:halt, result}
      {{:emit, new_signal}, new_state} -> {:emit, new_signal, new_state}
      {{:skip, _}, new_state} -> {:skip, new_state}
      {{:halt, result}, _} -> {:halt, result}
    end
  end

  defp handle_with({:emit, new_signal, state}, handler, _signal) do
    handle_with({:skip, state}, handler, new_signal)
  end

  defp handle_with(state, handler, signal) when is_map(state) do
    case handler.(signal, state) do
      {:skip, new_state} -> {:skip, new_state}
      {:emit, new_signal} -> {:emit, new_signal, state}
      {:halt, result} -> {:halt, result}
      {{:emit, new_signal}, new_state} -> {:emit, new_signal, new_state}
      {{:skip, _}, new_state} -> {:skip, new_state}
      {{:halt, result}, _} -> {:halt, result}
    end
  end
end
