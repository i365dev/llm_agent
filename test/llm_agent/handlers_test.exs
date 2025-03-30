defmodule LLMAgent.HandlersTest do
  @moduledoc """
  Tests for the LLMAgent.Handlers module.
  Verifies signal handling functionality.
  """

  use ExUnit.Case

  alias LLMAgent.{Handlers, Signals, Store}

  setup do
    store_name = String.to_atom("handler_test_#{System.unique_integer([:positive])}")
    store = Store.start_link(name: store_name)

    on_exit(fn ->
      if pid = Process.whereis(store_name) do
        Process.exit(pid, :normal)
      end
    end)

    %{store_name: store_name}
  end

  describe "message_handler/2" do
    test "processes a user message and updates store", %{store_name: store_name} do
      # Setup
      message = "What is the weather like today?"
      signal = Signals.user_message(message)
      state = %{store_name: store_name}

      # Execute handler
      {result, _updated_state} = Handlers.message_handler(signal, state)

      # Verify store updates
      history = Store.get_llm_history(store_name)
      assert length(history) > 0
      assert Enum.any?(history, &(&1.role == "user" and &1.content == message))

      # Verify result type
      assert match?({{:emit, _}, _}, result)
    end
  end

  describe "thinking_handler/2" do
    test "processes a thinking signal and updates store", %{store_name: store_name} do
      # Setup initial state
      Store.add_message(store_name, "system", "You are a helpful assistant.")
      Store.add_message(store_name, "user", "What's the weather like today?")

      # Setup thinking signal
      thought = "I need to check the weather API"
      signal = Signals.thinking(thought, 1)
      state = %{store_name: store_name}

      # Execute handler
      {result, _updated_state} = Handlers.thinking_handler(signal, state)

      # Verify thoughts were stored
      thoughts = Store.get_thoughts(store_name)
      assert thought in thoughts

      # Verify result format
      assert match?({{:emit, _signal}, _}, result)

      # Extract the signal for validation
      {{:emit, signal}, _} = result
      assert is_map(signal)
      assert Map.has_key?(signal, :type)
      assert signal.type in [:tool_call, :response, :thinking]
    end
  end

  describe "tool_handler/2" do
    test "processes a tool call and updates store", %{store_name: store_name} do
      # Setup a calculator tool
      tool_name = "calculator"
      args = %{expression: "1 + 2"}
      signal = Signals.tool_call(tool_name, args)

      # Create state with tool
      calculator = %{
        name: "calculator",
        description: "Performs calculations",
        execute: fn %{"expression" => expr} ->
          {result, _} = Code.eval_string(expr)
          %{result: result}
        end
      }

      state = %{
        store_name: store_name,
        available_tools: [calculator],
        tool_registry: fn name ->
          if name == "calculator" do
            {:ok, calculator.execute}
          else
            {:error, "Tool not found"}
          end
        end
      }

      # Execute handler
      {result, _updated_state} = Handlers.tool_handler(signal, state)

      # Verify tool call was recorded
      history = Store.get_llm_history(store_name)
      assert Enum.any?(history, &(&1.role == "function" and &1.name == tool_name))

      # Verify result
      assert match?({{:emit, _}, _}, result)
      {{:emit, signal}, _} = result
      assert signal.type == :tool_result
    end

    test "handles tool errors gracefully", %{store_name: store_name} do
      tool_name = "error_tool"
      args = %{}
      signal = Signals.tool_call(tool_name, args)

      state = %{
        store_name: store_name,
        tool_registry: fn _name -> {:error, "Tool not found"} end
      }

      # Execute handler
      {result, _updated_state} = Handlers.tool_handler(signal, state)

      # Verify error was recorded
      history = Store.get_llm_history(store_name)

      assert Enum.any?(
               history,
               &(&1.role == "assistant" and String.contains?(&1.content, "error"))
             )

      # Verify error signal
      assert match?({{:emit, %{type: :error}}, _}, result)
    end
  end

  describe "tool_result_handler/2" do
    test "processes tool result and updates store", %{store_name: store_name} do
      # Setup initial state
      Store.add_message(store_name, "system", "You are a helpful assistant.")
      Store.add_message(store_name, "user", "What is 40 + 2?")

      # Setup tool result
      tool_name = "calculator"
      tool_result = %{result: 42}
      signal = Signals.tool_result(tool_name, tool_result)

      state = %{
        store_name: store_name,
        available_tools: []
      }

      # Execute handler
      {result, _updated_state} = Handlers.tool_result_handler(signal, state)

      # Verify tool result was recorded
      history = Store.get_llm_history(store_name)
      assert Enum.any?(history, &(&1.role == "function" and &1.name == tool_name))

      # Verify response
      assert match?({{:emit, _}, _}, result)
    end
  end

  describe "response_handler/2" do
    test "processes response with custom formatter", %{store_name: store_name} do
      content = "The result is 42"
      signal = Signals.response(content)

      formatter = fn content -> "Formatted: #{content}" end
      state = %{store_name: store_name, response_formatter: formatter}

      {result, _updated_state} = Handlers.response_handler(signal, state)

      assert match?({{:halt, %{data: "Formatted: " <> _}}, _}, result)
    end

    test "processes response without formatter", %{store_name: store_name} do
      content = "The result is 42"
      signal = Signals.response(content)
      state = %{store_name: store_name}

      {result, _updated_state} = Handlers.response_handler(signal, state)

      assert match?({{:halt, %{data: ^content}}, _}, result)
    end
  end

  describe "error_handler/2" do
    test "processes error and updates store", %{store_name: store_name} do
      # Setup error signal
      message = "API rate limit exceeded"
      source = "tool_call"
      signal = Signals.error(message, source)
      state = %{store_name: store_name}

      # Execute handler
      {result, _updated_state} = Handlers.error_handler(signal, state)

      # Verify error was recorded in history
      history = Store.get_llm_history(store_name)

      assert Enum.any?(
               history,
               &(&1.role == "assistant" and String.contains?(&1.content, "error"))
             )

      # Verify response signal
      assert match?({{:emit, %{type: :response}}, _}, result)
    end

    test "handles different error types correctly", %{store_name: store_name} do
      error_types = [
        {"llm_call", "LLM API error"},
        {"tool_call", "Tool not found"},
        {"tool_result", "Invalid result format"},
        {"unknown", "Generic error"}
      ]

      Enum.each(error_types, fn {source, message} ->
        signal = Signals.error(message, source)
        state = %{store_name: store_name}

        {result, _} = Handlers.error_handler(signal, state)
        assert match?({{:emit, %{type: :response}}, _}, result)
      end)
    end
  end
end
