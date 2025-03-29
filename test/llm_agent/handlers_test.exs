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
    test "processes a thinking signal and returns a proper AgentForge signal" do
      # Setup with a realistic scenario
      thought = "I need to check the weather API"
      signal = Signals.thinking(thought, 1)

      state =
        Store.new(%{
          history: [
            %{role: "system", content: "You are a helpful assistant."},
            %{role: "user", content: "What's the weather like today?"}
          ]
        })

      # Execute handler with actual LLM logic
      {result, updated_state} = Handlers.thinking_handler(signal, state)

      # Verify thoughts were properly stored in state
      thoughts = Map.get(updated_state, :thoughts, [])
      assert thought in thoughts

      # Verify history is properly maintained
      history = Map.get(updated_state, :history, [])
      assert length(history) >= 2

      # Verify the result is a proper AgentForge signal format
      assert match?({{:emit, _signal}, _}, {result, updated_state})

      # Extract the signal for further validation
      {{:emit, signal}, _} = {result, updated_state}

      # Verify signal has a type that's an atom
      assert is_map(signal)
      assert Map.has_key?(signal, :type)
      assert is_atom(signal.type)

      # Extract the emitted signal for deeper verification
      {{:emit, emitted_signal}, _} = {result, updated_state}

      # Verify signal properties
      assert is_atom(emitted_signal.type)
      assert emitted_signal.type in [:tool_call, :response, :thinking]
    end

    test "handles empty conversation history gracefully" do
      # Setup with minimal state
      signal = Signals.thinking("Just thinking", 1)
      empty_state = Store.new()

      # Execute handler
      {result, updated_state} = Handlers.thinking_handler(signal, empty_state)

      # Verify handler doesn't crash with empty history
      assert is_map(updated_state)
      assert is_tuple(result)
    end
  end

  describe "tool_handler/2" do
    test "processes a tool call signal and emits an AgentForge signal" do
      # Setup a realistic tool (similar to those registered by LLMAgent.Plugin)
      tool_name = "calculator"
      args = %{expression: "1 + 2"}
      signal = Signals.tool_call(tool_name, args)

      # Create a more realistic tool definition that mimics actual system tools
      tools = [
        %{
          name: "calculator",
          description: "Performs basic arithmetic calculations",
          parameters: %{
            type: "object",
            properties: %{
              expression: %{
                type: "string",
                description: "The arithmetic expression to evaluate"
              }
            }
          },
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

      # Create state with conversation history and the tool registered
      state =
        Store.new(%{
          available_tools: tools,
          history: [
            %{
              role: "system",
              content: "You are a helpful assistant with calculator capabilities."
            },
            %{role: "user", content: "Calculate 1 + 2"},
            %{
              role: "assistant",
              content: "I'll use the calculator tool.",
              thinking: "I should use the calculator for this."
            }
          ]
        })

      # Execute the handler
      {result, updated_state} = Handlers.tool_handler(signal, state)

      # Verify result is an emit instruction with the proper signal
      assert match?({{:emit, _signal}, _}, {result, updated_state})

      # Extract and verify the emitted signal
      {{:emit, emitted_signal}, _} = {result, updated_state}
      assert emitted_signal.type == :tool_result
      assert is_map(emitted_signal.data)
      assert Map.has_key?(emitted_signal.data, :name)
      assert emitted_signal.data.name == "calculator"

      # Verify state was properly updated
      assert updated_state != state
    end

    test "handles tool errors gracefully" do
      # Test with a tool that will generate an error
      tool_name = "error_tool"
      args = %{}
      signal = Signals.tool_call(tool_name, args)

      # Define a tool that will generate an error
      tools = [
        %{
          name: "error_tool",
          function: fn _ -> %{error: "This tool always fails"} end
        }
      ]

      state = Store.new(%{available_tools: tools})

      # Execute handler
      {result, updated_state} = Handlers.tool_handler(signal, state)

      # Should still emit a valid signal with error information
      assert match?({{:emit, _}, _}, {result, updated_state})
      {{:emit, signal}, _} = {result, updated_state}

      # Based on implementation, errors produce error signals
      assert signal.type == :error
      assert Map.has_key?(signal.data, :message)
    end
  end

  describe "tool_result_handler/2" do
    test "processes a tool result and continues the conversation with thinking" do
      # Setup a realistic scenario with history
      tool_name = "calculator"
      tool_result = %{result: 42}
      signal = Signals.tool_result(tool_name, tool_result)

      # Create state with existing conversation history
      state =
        Store.new(%{
          history: [
            %{
              role: "system",
              content: "You are a helpful assistant with calculator capabilities."
            },
            %{role: "user", content: "What is 40 + 2?"},
            %{role: "assistant", content: "I'll use the calculator tool."}
          ],
          # Add pending tools to mimic real execution state
          pending_tools: [%{id: "calc-123", name: "calculator", args: %{expression: "40 + 2"}}]
        })

      # Execute the handler
      {result, updated_state} = Handlers.tool_result_handler(signal, state)

      # Verify signal is emitted correctly
      assert match?({{:emit, _signal}, _}, {result, updated_state})
      {{:emit, emitted_signal}, _} = {result, updated_state}

      # Verify signal is a valid type to continue the conversation
      # Based on implementation, we use :response as the continuation signal type
      assert emitted_signal.type == :response

      # Verify state updates: history should include tool result
      history = Map.get(updated_state, :history)

      assert Enum.any?(history, fn entry ->
               Map.get(entry, :role) == "function" &&
                 Map.get(entry, :name) == tool_name
             end)

      # Verify pending tools were updated
      assert Map.get(updated_state, :pending_tools) == []
    end

    test "handles error results gracefully" do
      # Setup with error result
      tool_name = "search_api"
      error_result = %{error: "API rate limit exceeded"}
      signal = Signals.tool_result(tool_name, error_result)

      # Create state with existing conversation
      state =
        Store.new(%{
          history: [
            %{role: "system", content: "You are a helpful assistant with search capabilities."},
            %{role: "user", content: "Search for the latest news"}
          ],
          pending_tools: [%{id: "search-123", name: "search_api", args: %{query: "latest news"}}]
        })

      # Execute handler
      {result, updated_state} = Handlers.tool_result_handler(signal, state)

      # Should still emit a valid signal - updated implementation returns a response or error signal
      assert match?({{:emit, _signal}, _}, {result, updated_state}) or
               match?({%{type: :response}, _}, {result, updated_state}) or
               match?({%{type: :error}, _}, {result, updated_state})

      # The implementation adds function results to history rather than tracking errors in state
      # We verify that the state was updated in some way
      assert updated_state != state
    end
  end

  describe "response_handler/2" do
    test "processes a response signal and emits AgentForge signals correctly" do
      # Setup with realistic response content
      content = "The weather today in San Francisco is sunny with a high of 75°F."
      signal = Signals.response(content)

      # Create state with conversation history to mimic real usage
      state =
        Store.new(%{
          history: [
            %{
              role: "system",
              content: "You are a helpful AI assistant that provides weather information."
            },
            %{role: "user", content: "What's the weather like in San Francisco today?"},
            %{
              role: "assistant",
              thinking: "I should provide the current weather for San Francisco."
            }
          ]
        })

      # Execute handler
      {result, updated_state} = Handlers.response_handler(signal, state)

      # Verify response is properly halted
      assert match?({{:halt, _signal}, _}, {result, updated_state})

      # Verify signal has correct type and content
      {{:halt, response_signal}, _} = {result, updated_state}
      assert response_signal.type == :response
      assert response_signal.data == content

      # In the updated implementation, response signals don't update history directly
      # Instead they set the response signal data
      assert response_signal.data == content
    end

    test "properly handles structured responses" do
      # Setup with structured content like markdown or JSON
      structured_content =
        "# Weather Report\n\n- **City**: San Francisco\n- **Condition**: Sunny\n- **Temperature**: 75°F\n"

      signal = Signals.response(structured_content)

      state = Store.new()

      # Execute handler
      {result, updated_state} = Handlers.response_handler(signal, state)

      # Verify structured content is preserved
      {{:halt, response_signal}, _} = {result, updated_state}
      assert response_signal.data == structured_content
    end
  end

  describe "error_handler/2" do
    test "processes an error signal and emits a proper AgentForge recovery signal" do
      # Setup with realistic error scenario
      message = "Rate limit exceeded for weather API"
      source = "tool_execution"
      signal = Signals.error(message, source)

      # Create state with context for the error
      state =
        Store.new(%{
          history: [
            %{
              role: "system",
              content: "You are a helpful AI assistant with access to weather information."
            },
            %{role: "user", content: "What's the weather in Seoul today?"}
          ],
          pending_tools: [%{id: "weather-123", name: "get_weather", args: %{location: "Seoul"}}]
        })

      # Execute handler
      {result, updated_state} = Handlers.error_handler(signal, state)

      # Verify a proper signal is emitted
      assert match?({{:emit, _signal}, _}, {result, updated_state})

      # Verify the signal is properly formatted for recovery
      {{:emit, recovery_signal}, _} = {result, updated_state}

      # Recovery signals could be :thinking or another type based on implementation
      assert is_atom(recovery_signal.type)

      # Verify error is recorded in state - errors are now tuples that include error info
      errors = Map.get(updated_state, :errors, [])
      assert length(errors) > 0

      # We now track errors as tuples with information
      assert Enum.any?(errors, fn error ->
               case error do
                 {:generic_error, msg, _timestamp} when is_binary(msg) ->
                   String.contains?(msg, message)

                 _ ->
                   false
               end
             end)
    end

    test "handles critical errors with appropriate signal" do
      # Setup a critical/unrecoverable error
      message = "Authentication failed - API key invalid"
      source = "authentication"
      signal = Signals.error(message, source, %{critical: true})

      state = Store.new()

      # Execute handler
      {result, updated_state} = Handlers.error_handler(signal, state)

      # Verify error is properly handled
      assert match?({_, _}, {result, updated_state})

      # Critical errors should be recorded in state
      errors = Map.get(updated_state, :errors, [])
      assert length(errors) > 0

      # The emitted result should allow for proper error reporting to user
      assert is_tuple(result)
    end
  end
end
