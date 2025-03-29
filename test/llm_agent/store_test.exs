defmodule LLMAgent.StoreTest do
  @moduledoc """
  Tests for the LLMAgent.Store module.
  Verifies state management functionality.
  """

  use ExUnit.Case

  alias LLMAgent.Store
  alias AgentForge.Store, as: AFStore

  setup do
    # 使用唯一存储名称避免测试间干扰
    store_name = String.to_atom("store_test_#{System.unique_integer([:positive])}")
    store = Store.new(%{}, name: store_name)

    on_exit(fn ->
      # 清理存储如果仍然存在
      case Process.whereis(store_name) do
        nil -> :ok
        pid -> Process.exit(pid, :normal)
      end
    end)

    %{store: store}
  end

  describe "store initialization" do
    test "creates a new store with default values", %{store: store} do
      # Store is now a process name
      assert is_atom(store)

      {:ok, history} = AFStore.get(store, :history)
      assert history == []

      {:ok, thoughts} = AFStore.get(store, :thoughts)
      assert thoughts == []

      {:ok, tool_calls} = AFStore.get(store, :tool_calls)
      assert tool_calls == []
    end

    test "creates a new store with initial values" do
      initial_state = %{
        history: [%{role: "system", content: "You are a helpful assistant"}],
        available_tools: [%{name: "calculator", description: "Performs calculations"}]
      }

      store_name = String.to_atom("store_test_init_values")
      store = Store.new(initial_state, name: store_name)

      # Store is now a process name
      assert is_atom(store)

      {:ok, history} = AFStore.get(store, :history)

      assert history == [
               %{role: "system", content: "You are a helpful assistant"}
             ]

      {:ok, thoughts} = AFStore.get(store, :thoughts)
      assert thoughts == []

      {:ok, available_tools} = AFStore.get(store, :available_tools)

      assert available_tools == [
               %{name: "calculator", description: "Performs calculations"}
             ]

      # 清理测试后创建的 store
      Process.exit(Process.whereis(store_name), :normal)
    end
  end

  describe "message management" do
    test "adds a user message to history", %{store: store} do
      message = "Hello, assistant"
      :ok = Store.add_message(store, "user", message)

      {:ok, history} = AFStore.get(store, :history)
      assert length(history) == 1
      [added_message] = history
      assert added_message.role == "user"
      assert added_message.content == message
    end

    test "adds an assistant message to history", %{store: store} do
      message = "I can help with that"
      :ok = Store.add_message(store, "assistant", message)

      {:ok, history} = AFStore.get(store, :history)
      assert length(history) == 1
      [added_message] = history
      assert added_message.role == "assistant"
      assert added_message.content == message
    end

    test "gets LLM history in the correct format", %{store: store} do
      :ok = Store.add_message(store, "system", "You are a helpful assistant")
      :ok = Store.add_message(store, "user", "Hello")
      :ok = Store.add_message(store, "assistant", "Hi there")

      history = Store.get_llm_history(store)

      assert length(history) == 3

      assert Enum.all?(history, fn msg ->
               Map.has_key?(msg, :role) && Map.has_key?(msg, :content)
             end)
    end
  end

  describe "thought management" do
    test "adds a thought", %{store: store} do
      thought = "I should answer the user's question directly"
      :ok = Store.add_thought(store, thought)

      {:ok, thoughts} = AFStore.get(store, :thoughts)
      assert length(thoughts) == 1
      assert List.first(thoughts) == thought
    end

    test "gets all thoughts", %{store: store} do
      thoughts = ["First thought", "Second thought"]

      Enum.each(thoughts, fn thought ->
        :ok = Store.add_thought(store, thought)
      end)

      retrieved_thoughts = Store.get_thoughts(store)
      assert retrieved_thoughts == thoughts
    end
  end

  describe "tool call management" do
    test "adds a tool call", %{store: store} do
      tool_name = "calculator"
      args = %{expression: "1 + 2"}
      result = %{output: 3}
      :ok = Store.add_tool_call(store, tool_name, args, result)

      {:ok, tool_calls} = AFStore.get(store, :tool_calls)
      assert length(tool_calls) == 1
      [tool_call] = tool_calls
      assert tool_call.name == tool_name
      assert tool_call.args == args
      assert tool_call.result == result
    end
  end
end
