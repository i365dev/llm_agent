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
end
