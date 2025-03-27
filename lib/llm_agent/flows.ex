defmodule LLMAgent.Flows do
  @moduledoc """
  Provides standard flow definitions for common LLM agent patterns.

  This module creates AgentForge flow compositions for different LLM agent use cases,
  such as conversational agents and task-based agents. It registers tools, creates
  appropriate handlers, and configures initial state.
  """

  alias LLMAgent.{Store, Handlers}

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
    # Create initial store with system prompt in history
    initial_state =
      Store.new(%{
        history: [%{role: "system", content: system_prompt}],
        available_tools: tools
      })

    # Add any custom options to state
    initial_state = Map.merge(initial_state, Map.new(options))

    # Register tools with AgentForge.Tools
    register_tools(tools)

    # Create flow with standard handlers
    flow = fn signal, state ->
      handlers = [
        &Handlers.message_handler/2,
        &Handlers.thinking_handler/2,
        &Handlers.tool_handler/2,
        &Handlers.tool_result_handler/2,
        &Handlers.task_handler/2,
        &Handlers.response_handler/2,
        &Handlers.error_handler/2
      ]

      # Apply handlers in sequence
      Enum.reduce_while(handlers, {signal, state}, fn handler, {current_signal, current_state} ->
        case handler.(current_signal, current_state) do
          {{:next, new_signal}, new_state} -> {:cont, {new_signal, new_state}}
          {{:emit, new_signal}, new_state} -> {:cont, {new_signal, new_state}}
          {{:done, new_signal}, new_state} -> {:halt, {new_signal, new_state}}
          {{:error, new_signal}, new_state} -> {:halt, {new_signal, new_state}}
        end
      end)
    end

    {flow, initial_state}
  end

  @doc """
  Creates a flow specific for processing long-running tasks.

  ## Parameters

  - `task_definition` - The task definition as a list of AgentForge primitives
  - `options` - Additional options for configuring the task flow

  ## Returns

  A flow that will execute the task primitives.

  ## Examples

      iex> task_def = [
      ...>   AgentForge.Primitives.transform(fn data -> Map.put(data, :step1, true) end)
      ...> ]
      iex> flow = LLMAgent.Flows.task_flow(task_def)
      iex> is_function(flow)
      true
  """
  def task_flow(task_definition, options \\ []) do
    # Get timeout from options or use default
    # 1 minute timeout
    _timeout_ms = Keyword.get(options, :timeout_ms, 60000)

    # Create flow with primitives handler
    fn signal, state ->
      # Use primitive handler to execute task primitives
      state_with_primitives = Map.put(state, :primitives, task_definition)

      # Execute primitives
      case AgentForge.Flow.process(task_definition, signal, state_with_primitives) do
        {:ok, result, new_state} ->
          {{:emit, result}, Map.drop(new_state, [:primitives])}

        {:error, reason} ->
          {{:emit, LLMAgent.Signals.error(reason, "task_execution")}, state}
      end
    end
  end

  @doc """
  Creates a flow for processing batch requests (non-conversational).

  ## Parameters

  - `items` - A list of items to process
  - `batch_handler` - A function that processes each item
  - `options` - Additional options for configuring the batch flow

  ## Returns

  A flow that will process batch requests.

  ## Examples

      iex> processor = fn signal, state -> {{:emit, signal}, state} end
      iex> flow = LLMAgent.Flows.batch_processing([], processor, [])
      iex> is_function(flow)
      true
  """
  def batch_processing(items, _batch_handler, _options \\ []) do
    # Create a flow that will process each item in the batch

    # Create flow with batch processing handler
    fn signal, state ->
      # Initialize batch state
      batch = Map.get(state, :batch, %{items: items, index: 0})

      if batch.index < length(batch.items) do
        item = Enum.at(batch.items, batch.index)
        {{:next, item}, Map.put(state, :batch, %{batch | index: batch.index + 1})}
      else
        {{:done, signal}, state}
      end
    end
  end

  @doc """
  Creates a flow for a simple question-answering agent.

  ## Parameters

  - `system_prompt` - The system prompt that defines the agent's behavior
  - `options` - Additional options for configuring the agent

  ## Returns

  A tuple containing the flow and initial state for the agent.

  ## Examples

      iex> {flow, state} = LLMAgent.Flows.qa_agent("You are a helpful question-answering assistant.")
      iex> is_function(flow) and is_map(state)
      true
  """
  def qa_agent(system_prompt, options \\ []) do
    # Create a simple QA agent with no tools
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
    # Register each tool with AgentForge.Tools
    Enum.each(tools, fn tool ->
      AgentForge.Tools.register(tool.name, fn args ->
        # Execute the tool function
        try do
          tool.execute.(args)
        rescue
          e -> %{error: Exception.message(e)}
        end
      end)
    end)
  end
end
