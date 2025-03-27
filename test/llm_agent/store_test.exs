defmodule LLMAgent.StoreTest do
  @moduledoc """
  Tests for the LLMAgent.Store module.
  Verifies state management functionality.
  """

  use ExUnit.Case

  alias LLMAgent.Store

  describe "store initialization" do
    test "creates a new store with default values" do
      store = Store.new()

      assert is_map(store)
      assert Map.get(store, :history) == []
      assert Map.get(store, :thoughts) == []
      assert Map.get(store, :tool_calls) == []
    end

    test "creates a new store with initial values" do
      initial_state = %{
        history: [%{role: "system", content: "You are a helpful assistant"}],
        available_tools: [%{name: "calculator", description: "Performs calculations"}]
      }

      store = Store.new(initial_state)

      assert is_map(store)

      assert Map.get(store, :history) == [
               %{role: "system", content: "You are a helpful assistant"}
             ]

      assert Map.get(store, :thoughts) == []

      assert Map.get(store, :available_tools) == [
               %{name: "calculator", description: "Performs calculations"}
             ]
    end
  end

  describe "message management" do
    test "adds a user message to history" do
      store = Store.new()
      message = "Hello, assistant"
      updated_store = Store.add_message(store, "user", message)

      assert length(Map.get(updated_store, :history)) == 1
      [added_message] = Map.get(updated_store, :history)
      assert added_message.role == "user"
      assert added_message.content == message
    end

    test "adds an assistant message to history" do
      store = Store.new()
      message = "I can help with that"
      updated_store = Store.add_message(store, "assistant", message)

      assert length(Map.get(updated_store, :history)) == 1
      [added_message] = Map.get(updated_store, :history)
      assert added_message.role == "assistant"
      assert added_message.content == message
    end

    test "gets LLM history in the correct format" do
      store =
        Store.new()
        |> Store.add_message("system", "You are a helpful assistant")
        |> Store.add_message("user", "Hello")
        |> Store.add_message("assistant", "Hi there")

      history = store.history

      assert length(history) == 3

      assert Enum.all?(history, fn msg ->
               Map.has_key?(msg, :role) && Map.has_key?(msg, :content)
             end)
    end
  end

  describe "thought management" do
    test "adds a thought" do
      store = Store.new()
      thought = "I should answer the user's question directly"
      updated_store = Store.add_thought(store, thought)

      thoughts = Map.get(updated_store, :thoughts)
      assert length(thoughts) == 1
      assert List.first(thoughts) == thought
    end

    test "gets all thoughts" do
      thoughts = ["First thought", "Second thought"]
      store = Store.new()

      updated_store =
        Enum.reduce(thoughts, store, fn thought, acc ->
          Store.add_thought(acc, thought)
        end)

      retrieved_thoughts = updated_store.thoughts
      assert retrieved_thoughts == thoughts
    end
  end

  describe "tool call management" do
    test "adds a tool call" do
      store = Store.new()
      tool_name = "calculator"
      args = %{expression: "1 + 2"}
      result = %{output: 3}
      updated_store = Store.add_tool_call(store, tool_name, args, result)

      tool_calls = Map.get(updated_store, :tool_calls, [])
      assert length(tool_calls) == 1
      [tool_call] = tool_calls
      assert tool_call.name == tool_name
      assert tool_call.args == args
      assert tool_call.result == result
    end
  end
end
