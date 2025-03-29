defmodule LLMAgent.Store do
  @moduledoc """
  Manages state for LLM agent conversations.

  This module provides helpers for working with the LLM agent state, including
  managing conversation history, thoughts, tool calls, and tasks. It follows
  AgentForge's immutable state pattern.
  """

  @doc """
  Creates a new store with default values.

  ## Parameters

  - `attrs` - A map of attributes to merge with the default store

  ## Returns

  A new store map with default values merged with the provided attributes.

  ## Examples

      iex> store = LLMAgent.Store.new()
      iex> is_list(store.history) and is_list(store.thoughts) and is_list(store.tool_calls)
      true
      
      iex> store = LLMAgent.Store.new(%{user_id: "123"})
      iex> store.user_id
      "123"
  """
  def new(attrs \\ %{}) do
    Map.merge(
      %{
        history: [],
        thoughts: [],
        tool_calls: [],
        current_tasks: [],
        preferences: %{}
      },
      attrs
    )
  end

  @doc """
  Adds a message to history.

  ## Parameters

  - `state` - The current store state
  - `role` - The role of the message (e.g., "user", "assistant", "system")
  - `content` - The content of the message

  ## Returns

  An updated state with the new message added to history.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_message(state, "user", "Hello")
      iex> [%{role: "user", content: "Hello"}] = state.history
  """
  def add_message(state, role, content) do
    Map.update(state, :history, [], &(&1 ++ [%{role: role, content: content}]))
  end

  @doc """
  Adds a thought to the current processing cycle.

  ## Parameters

  - `state` - The current store state
  - `thought` - The thought content

  ## Returns

  An updated state with the new thought added to the thoughts list.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_thought(state, "I should look up stock prices")
      iex> ["I should look up stock prices"] = state.thoughts
  """
  def add_thought(state, thought) do
    Map.update(state, :thoughts, [], &(&1 ++ [thought]))
  end

  @doc """
  Adds a tool call record to the state.

  ## Parameters

  - `state` - The current store state
  - `name` - The name of the tool
  - `args` - The arguments passed to the tool
  - `result` - The result of the tool call

  ## Returns

  An updated state with the new tool call record added.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_tool_call(state, "get_weather", %{city: "New York"}, %{temp: 72})
      iex> [%{name: "get_weather", args: %{city: "New York"}, result: %{temp: 72}}] = state.tool_calls
  """
  def add_tool_call(state, name, args, result) do
    Map.update(state, :tool_calls, [], &(&1 ++ [%{name: name, args: args, result: result}]))
  end

  @doc """
  Gets LLM history in the format expected by LLM providers.

  ## Parameters

  - `state` - The current store state
  - `max_length` - The maximum number of history entries to return (default: 10)

  ## Returns

  A list of history entries, limited to the specified maximum length.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_message(state, "system", "You are a helpful assistant.")
      iex> state = LLMAgent.Store.add_message(state, "user", "Hello")
      iex> history = LLMAgent.Store.get_llm_history(state)
      iex> length(history) == 2
      true
  """
  def get_llm_history(state, max_length \\ 10) do
    state
    |> Map.get(:history, [])
    |> Enum.take(-max_length)
  end

  @doc """
  Gets all thoughts for the current processing cycle.

  ## Parameters

  - `state` - The current store state

  ## Returns

  A list of thoughts from the current processing cycle.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_thought(state, "First thought")
      iex> state = LLMAgent.Store.add_thought(state, "Second thought")
      iex> thoughts = LLMAgent.Store.get_thoughts(state)
      iex> length(thoughts) == 2
      true
  """
  def get_thoughts(state) do
    Map.get(state, :thoughts, [])
  end

  @doc """
  Adds a task to the current tasks list.

  ## Parameters

  - `state` - The current store state
  - `task` - The task to add

  ## Returns

  An updated state with the new task added to the current tasks list.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> task = %{id: "task_123", type: "analysis", status: "running"}
      iex> state = LLMAgent.Store.add_task(state, task)
      iex> [%{id: "task_123"}] = state.current_tasks
  """
  def add_task(state, task) do
    Map.update(state, :current_tasks, [], &(&1 ++ [task]))
  end

  @doc """
  Updates task state for a specific task.

  ## Parameters

  - `state` - The current store state
  - `task_id` - The ID of the task to update
  - `new_state` - The new state for the task

  ## Returns

  An updated state with the task state updated.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> task = %{id: "task_123", status: "running"}
      iex> state = LLMAgent.Store.add_task(state, task)
      iex> state = LLMAgent.Store.update_task_state(state, "task_123", "completed")
      iex> [%{id: "task_123", status: "completed"}] = state.current_tasks
  """
  def update_task_state(state, task_id, new_task_state) do
    updated_tasks =
      state
      |> Map.get(:current_tasks, [])
      |> Enum.map(fn
        %{id: ^task_id} = task -> Map.put(task, :status, new_task_state)
        task -> task
      end)

    Map.put(state, :current_tasks, updated_tasks)
  end

  @doc """
  Sets user preferences in the state.

  ## Parameters

  - `state` - The current store state
  - `preferences` - The preferences to set

  ## Returns

  An updated state with the preferences merged into the existing preferences.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.set_preferences(state, %{language: "en"})
      iex> state.preferences.language
      "en"
  """
  def set_preferences(state, preferences) do
    Map.update(state, :preferences, preferences, &Map.merge(&1, preferences))
  end

  @doc """
  Adds an error record to the state.

  ## Parameters

  - `state` - The current store state
  - `error` - The error record, typically in the form of a tuple with error type, message, and timestamp

  ## Returns

  An updated state with the new error record added.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_error(state, {:llm_error, "Service unavailable", DateTime.utc_now()})
      iex> [error] = state.errors
      iex> elem(error, 0) == :llm_error
      true
  """
  def add_error(state, error) do
    Map.update(state, :errors, [error], &(&1 ++ [error]))
  end

  @doc """
  Adds a function result to the state, useful for tracking tool execution outcomes.

  ## Parameters

  - `state` - The current store state
  - `function_name` - The name of the function/tool
  - `result` - The result returned by the function

  ## Returns

  An updated state with the function result added to history in a format compatible with LLM context.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_function_result(state, "get_weather", %{temp: 72})
      iex> Enum.any?(state.history, fn msg -> msg.role == "function" end)
      true
  """
  def add_function_result(state, function_name, result) do
    # Convert result to string if it's not already
    result_str =
      if is_binary(result) do
        result
      else
        Jason.encode!(result, pretty: true)
      end

    # Add function result as a message in history
    Map.update(
      state,
      :history,
      [],
      &(&1 ++ [%{role: "function", name: function_name, content: result_str}])
    )
  end

  @doc """
  Gets a specific user preference.

  ## Parameters

  - `state` - The current store state
  - `key` - The preference key to get
  - `default` - The default value to return if the preference is not set

  ## Returns

  The preference value or the default value.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.set_preferences(state, %{language: "en"})
      iex> LLMAgent.Store.get_preference(state, :language, "fr")
      "en"
      iex> LLMAgent.Store.get_preference(state, :theme, "dark")
      "dark"
  """
  def get_preference(state, key, default \\ nil) do
    state
    |> Map.get(:preferences, %{})
    |> Map.get(key, default)
  end

  @doc """
  Gets all preferences from the state.

  ## Parameters

  - `state` - The current store state

  ## Returns

  A map of preferences.

  ## Examples

      iex> state = LLMAgent.Store.new(%{preferences: %{theme: "dark"}})
      iex> LLMAgent.Store.get_preferences(state)
      %{theme: "dark"}
  """
  def get_preferences(state) do
    Map.get(state, :preferences, %{})
  end

  @doc """
  Trims history to a maximum number of entries while preserving system messages.

  This function is useful for managing memory usage in long conversations.
  System messages are always preserved, and the most recent user/assistant 
  messages are kept up to the specified limit.

  ## Parameters

  - `state` - The current store state
  - `max_entries` - The maximum number of entries to keep (default: 50)

  ## Returns

  An updated state with trimmed history.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = LLMAgent.Store.add_message(state, "system", "You are an assistant")
      iex> # Add many user/assistant message pairs to exceed the limit
      iex> state = Enum.reduce(1..60, state, fn n, acc -> 
      ...>   acc = LLMAgent.Store.add_message(acc, "user", "Message " <> Integer.to_string(n))
      ...>   LLMAgent.Store.add_message(acc, "assistant", "Response " <> Integer.to_string(n))
      ...> end)
      iex> trimmed_state = LLMAgent.Store.trim_history(state)
      iex> length(trimmed_state.history) <= 51  # 50 + 1 system message
      true
      iex> # Verify system message is preserved
      iex> Enum.any?(trimmed_state.history, fn msg -> msg.role == "system" end)
      true
  """
  def trim_history(state, max_entries \\ 50) do
    history = Map.get(state, :history, [])

    if length(history) > max_entries do
      # Separate system messages and other messages
      {system_messages, other_messages} =
        Enum.split_with(history, fn msg -> msg.role == "system" end)

      # Keep the most recent messages up to the limit
      recent_messages =
        other_messages
        |> Enum.reverse()
        |> Enum.take(max_entries - length(system_messages))
        |> Enum.reverse()

      # Create new history with system messages first followed by recent messages
      Map.put(state, :history, system_messages ++ recent_messages)
    else
      state
    end
  end

  @doc """
  Prunes the thoughts list to a maximum size to prevent memory bloat.

  ## Parameters

  - `state` - The current store state
  - `max_thoughts` - The maximum number of thoughts to keep (default: 20)

  ## Returns

  An updated state with pruned thoughts.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> state = Enum.reduce(1..30, state, fn n, acc -> LLMAgent.Store.add_thought(acc, "Thought " <> Integer.to_string(n)) end)
      iex> pruned_state = LLMAgent.Store.prune_thoughts(state)
      iex> length(pruned_state.thoughts) <= 20
      true
  """
  def prune_thoughts(state, max_thoughts \\ 20) do
    thoughts = Map.get(state, :thoughts, [])

    if length(thoughts) > max_thoughts do
      # Keep the most recent thoughts
      recent_thoughts = thoughts |> Enum.reverse() |> Enum.take(max_thoughts) |> Enum.reverse()
      Map.put(state, :thoughts, recent_thoughts)
    else
      state
    end
  end

  @doc """
  Optimizes the state by trimming history and pruning thoughts.

  This is a utility function that combines trim_history and prune_thoughts
  to optimize the entire state at once.

  ## Parameters

  - `state` - The current store state
  - `options` - Options including :max_history and :max_thoughts

  ## Returns

  An optimized state.

  ## Examples

      iex> state = LLMAgent.Store.new()
      iex> # Add lots of history and thoughts
      iex> optimized_state = LLMAgent.Store.optimize(state, max_history: 30, max_thoughts: 10)
      iex> is_map(optimized_state)
      true
  """
  def optimize(state, options \\ []) do
    max_history = Keyword.get(options, :max_history, 50)
    max_thoughts = Keyword.get(options, :max_thoughts, 20)

    state
    |> trim_history(max_history)
    |> prune_thoughts(max_thoughts)
  end
end
