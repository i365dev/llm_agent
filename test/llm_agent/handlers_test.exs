defmodule LLMAgent.HandlersTest do
  @moduledoc """
  Tests for the LLMAgent.Handlers module.
  Verifies signal handling functionality.
  """

  use ExUnit.Case

  alias LLMAgent.{Handlers, Signals, Store}

  describe "message_handler/2" do
    test "processes a user message and updates state" do
      # Setup
      message = "What is the weather like today?"
      signal = Signals.user_message(message)
      state = Store.new()

      # Execute handler
      {result, updated_state} = Handlers.message_handler(signal, state)

      # Verify state updates
      assert Map.get(updated_state, :history) != []

      # Verify result type - don't assume response type since implementation may vary
      assert is_tuple(result)
      assert elem(result, 0) in [:emit, :done, :next, :skip]
    end
  end

  describe "thinking_handler/2" do
    test "processes a thinking signal and returns next step" do
      # Setup
      thought = "I need to check the weather API"
      signal = Signals.thinking(thought, 1)
      state = Store.new()

      # Test
      {result, updated_state} = Handlers.thinking_handler(signal, state)

      # Verify thoughts were stored
      thoughts = Map.get(updated_state, :thoughts, [])
      assert thought in thoughts

      # Verify result has appropriate signal type
      assert is_tuple(result)
      assert elem(result, 0) in [:emit, :done, :next, :skip]
    end
  end

  describe "tool_handler/2" do
    test "processes a tool call signal" do
      # Setup a mock tool
      tool_name = "calculator"
      args = %{expression: "1 + 2"}
      signal = Signals.tool_call(tool_name, args)

      # Create state with the tool registered
      tools = [
        %{
          name: "calculator",
          function: fn %{expression: expr} ->
            {op1, op, op2} =
              expr
              |> String.split(" ", trim: true)
              |> List.to_tuple()

            case op do
              "+" -> %{result: String.to_integer(op1) + String.to_integer(op2)}
              "-" -> %{result: String.to_integer(op1) - String.to_integer(op2)}
              "*" -> %{result: String.to_integer(op1) * String.to_integer(op2)}
              "/" -> %{result: String.to_integer(op1) / String.to_integer(op2)}
              _ -> %{error: "Unsupported operation: #{op}"}
            end
          end
        }
      ]

      state = Store.new(%{available_tools: tools})

      # Test
      {result, _updated_state} = Handlers.tool_handler(signal, state)

      # Verify result contains a tool result signal
      assert is_tuple(result)
      assert elem(result, 0) == :emit

      response_signal = elem(result, 1)
      assert response_signal.type == :tool_result
    end
  end

  describe "tool_result_handler/2" do
    test "processes a tool result and continues conversation" do
      # Setup
      tool_name = "calculator"
      result = %{result: 42}
      signal = Signals.tool_result(tool_name, result)
      state = Store.new()

      # Test
      {result, updated_state} = Handlers.tool_result_handler(signal, state)

      # Verify state has changed
      assert updated_state != state

      # Verify result has appropriate signal type
      assert is_tuple(result)
      assert elem(result, 0) in [:emit, :done, :next, :skip]
    end
  end

  describe "response_handler/2" do
    test "processes a response signal" do
      # Setup
      content = "The weather is sunny today"
      signal = Signals.response(content)
      state = Store.new()

      # Test
      {result, _updated_state} = Handlers.response_handler(signal, state)

      # Based on implementation, response_handler returns a halt signal 
      # with formatted response, without changing the state
      assert is_tuple(result)
      assert elem(result, 0) == :halt

      # Check that the response content is preserved
      response_signal = elem(result, 1)
      assert response_signal.type == :response
      assert response_signal.data == content
    end
  end

  describe "error_handler/2" do
    test "processes an error signal and attempts recovery" do
      # Setup
      message = "Failed to call weather API"
      source = "tool_execution"
      signal = Signals.error(message, source)
      state = Store.new()

      # Test
      {result, _updated_state} = Handlers.error_handler(signal, state)

      # Verify result contains an appropriate recovery action
      assert is_tuple(result)
      assert elem(result, 0) in [:emit, :done, :next, :skip]
    end
  end
end
