defmodule LLMAgent.StoreTest do
  @moduledoc """
  Tests for the LLMAgent.Store module.
  Verifies state management functionality.
  """

  use ExUnit.Case, async: true

  alias AgentForge.Store, as: AFStore
  alias LLMAgent.Store

  setup do
    store_name = String.to_atom("store_test_#{System.unique_integer([:positive])}")
    store = Store.new(%{}, name: store_name)

    on_exit(fn ->
      if pid = Process.whereis(store_name) do
        Process.exit(pid, :normal)
      end
    end)

    %{store: store}
  end

  describe "store initialization" do
    test "creates a new store with default values", %{store: store} do
      assert is_atom(store)
      assert {:ok, []} = AFStore.get(store, :history)
      assert {:ok, []} = AFStore.get(store, :thoughts)
      assert {:ok, []} = AFStore.get(store, :tool_calls)
      assert {:ok, []} = AFStore.get(store, :current_tasks)
      assert {:ok, %{}} = AFStore.get(store, :preferences)
    end

    test "creates a new store with initial values" do
      initial_state = %{
        history: [%{role: "system", content: "You are a helpful assistant"}],
        available_tools: [%{name: "calculator", description: "Performs calculations"}],
        preferences: %{language: "en"}
      }

      store_name = String.to_atom("store_test_init_values")
      store = Store.new(initial_state, name: store_name)

      assert is_atom(store)

      assert {:ok, [%{role: "system", content: "You are a helpful assistant"}]} =
               AFStore.get(store, :history)

      assert {:ok, []} = AFStore.get(store, :thoughts)

      assert {:ok, [%{name: "calculator", description: "Performs calculations"}]} =
               AFStore.get(store, :available_tools)

      assert {:ok, %{language: "en"}} = AFStore.get(store, :preferences)

      if pid = Process.whereis(store_name) do
        Process.exit(pid, :normal)
      end
    end
  end

  describe "message management" do
    test "adds messages to history and retrieves them correctly", %{store: store} do
      assert :ok = Store.add_message(store, "system", "You are a helpful assistant")
      assert :ok = Store.add_message(store, "user", "Hello")
      assert :ok = Store.add_message(store, "assistant", "Hi there")

      assert {:ok, history} = AFStore.get(store, :history)
      assert length(history) == 3

      assert [
               %{role: "system", content: "You are a helpful assistant"},
               %{role: "user", content: "Hello"},
               %{role: "assistant", content: "Hi there"}
             ] = history

      llm_history = Store.get_llm_history(store)
      assert length(llm_history) == 3

      assert Enum.all?(llm_history, fn msg ->
               Map.has_key?(msg, :role) && Map.has_key?(msg, :content)
             end)
    end

    test "handles empty history gracefully", %{store: store} do
      assert [] = Store.get_llm_history(store)
    end
  end

  describe "thought management" do
    test "manages thoughts correctly", %{store: store} do
      thoughts = ["First thought", "Second thought"]

      Enum.each(thoughts, fn thought ->
        assert :ok = Store.add_thought(store, thought)
      end)

      assert {:ok, stored_thoughts} = AFStore.get(store, :thoughts)
      assert stored_thoughts == thoughts
      assert Store.get_thoughts(store) == thoughts
    end

    test "handles empty thoughts list", %{store: store} do
      assert Store.get_thoughts(store) == []
    end
  end

  describe "tool call management" do
    test "manages tool calls correctly", %{store: store} do
      tool_name = "calculator"
      args = %{expression: "1 + 2"}
      result = %{output: 3}

      assert :ok = Store.add_tool_call(store, tool_name, args, result)
      assert {:ok, tool_calls} = AFStore.get(store, :tool_calls)
      assert [%{name: ^tool_name, args: ^args, result: ^result}] = tool_calls
    end

    test "handles multiple tool calls", %{store: store} do
      tool_calls = [
        {"calculator", %{expression: "1 + 2"}, %{output: 3}},
        {"weather", %{city: "London"}, %{temperature: 20}}
      ]

      Enum.each(tool_calls, fn {name, args, result} ->
        assert :ok = Store.add_tool_call(store, name, args, result)
      end)

      assert {:ok, stored_calls} = AFStore.get(store, :tool_calls)
      assert length(stored_calls) == 2
    end
  end

  describe "task management" do
    test "adds and updates tasks", %{store: store} do
      task = %{id: "task_123", type: "analysis", status: "running"}
      assert :ok = Store.add_task(store, task)

      updated_state =
        Store.update_task_state(
          %{current_tasks: [task]},
          "task_123",
          "completed"
        )

      assert [%{id: "task_123", status: "completed"}] = updated_state.current_tasks
    end
  end

  describe "preference management" do
    test "manages preferences correctly", %{store: store} do
      initial_state = %{preferences: %{theme: "dark"}}
      updated_state = Store.set_preferences(initial_state, %{language: "en"})

      assert updated_state.preferences == %{theme: "dark", language: "en"}
      assert Store.get_preferences(updated_state) == %{theme: "dark", language: "en"}
      assert Store.get_preference(updated_state, :theme) == "dark"
      assert Store.get_preference(updated_state, :missing, "default") == "default"
    end
  end

  describe "history optimization" do
    test "trims history while preserving system messages", %{store: store} do
      # Add system message
      :ok = Store.add_message(store, "system", "You are an assistant")

      # Add many messages to exceed the default limit
      Enum.each(1..60, fn n ->
        :ok = Store.add_message(store, "user", "Message #{n}")
        :ok = Store.add_message(store, "assistant", "Response #{n}")
      end)

      # Get current history length
      {:ok, history} = AFStore.get(store, :history)
      assert length(history) > 50

      # Trim history
      trimmed_state = Store.trim_history(%{history: history})
      # 50 + 1 system message
      assert length(trimmed_state.history) <= 51

      # Verify system message is preserved
      assert Enum.any?(trimmed_state.history, fn msg -> msg.role == "system" end)
    end
  end
end
