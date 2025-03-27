defmodule LLMAgent.SignalsTest do
  @moduledoc """
  Tests for the LLMAgent.Signals module.
  Verifies signal generation and structure.
  """

  use ExUnit.Case

  alias LLMAgent.Signals

  describe "signal creation" do
    test "creates a user_message signal" do
      message = "Hello, agent"
      signal = Signals.user_message(message)

      assert signal.type == :user_message
      assert signal.data == message
    end

    test "creates a thinking signal" do
      thought = "I'm thinking about this..."
      step = 2
      signal = Signals.thinking(thought, step)

      assert signal.type == :thinking
      assert signal.data == thought
      assert signal.meta.step == step
    end

    test "creates a tool_call signal" do
      tool_name = "calculator"
      args = %{input: "1 + 2"}
      signal = Signals.tool_call(tool_name, args)

      assert signal.type == :tool_call
      assert signal.data.name == tool_name
      assert signal.data.args == args
    end

    test "creates a tool_result signal" do
      tool_name = "calculator"
      result = %{output: 3}
      signal = Signals.tool_result(tool_name, result)

      assert signal.type == :tool_result
      assert signal.data.name == tool_name
      assert signal.data.result == result
    end

    test "creates a response signal" do
      content = "I can help with that"
      signal = Signals.response(content)

      assert signal.type == :response
      assert signal.data == content
    end

    test "creates an error signal" do
      message = "Something went wrong"
      source = "tool_execution"
      signal = Signals.error(message, source)

      assert signal.type == :error
      assert signal.data.message == message
      assert signal.data.source == source
    end

    test "creates a task_state signal" do
      task_id = "task-123"
      state = "running"
      signal = Signals.task_state(task_id, state)

      assert signal.type == :task_state
      assert signal.data.task_id == task_id
      assert signal.data.state == state
    end
  end
end
