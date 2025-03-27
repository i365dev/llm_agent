defmodule LLMAgent.Signals do
  @moduledoc """
  Defines LLM-specific signal types and helpers for agent communication.

  This module extends AgentForge.Signal with specialized signal types for LLM interactions,
  providing a consistent interface for creating signals that represent different stages
  of LLM agent processing.

  ## Signal Types

  - `:user_message` - A message from the user
  - `:system_message` - A system message
  - `:thinking` - An agent thinking step
  - `:tool_call` - A tool call request
  - `:tool_result` - A tool execution result
  - `:task_state` - A task state update
  - `:response` - An agent response
  - `:error` - An error signal
  """

  alias AgentForge.Signal

  @doc """
  Creates a user message signal.

  ## Parameters

  - `content` - The content of the user message
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:user_message` with the provided content and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.user_message("Hello")
      iex> signal.type == :user_message and signal.data == "Hello"
      true
      
      iex> signal = LLMAgent.Signals.user_message("Hello", %{user_id: "123"})
      iex> signal.meta.user_id
      "123"
  """
  def user_message(content, meta \\ %{}) do
    Signal.new(:user_message, content, meta)
  end

  @doc """
  Creates a system message signal.

  ## Parameters

  - `content` - The content of the system message
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:system_message` with the provided content and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.system_message("You are a helpful assistant.")
      iex> signal.type == :system_message and signal.data == "You are a helpful assistant."
      true
  """
  def system_message(content, meta \\ %{}) do
    Signal.new(:system_message, content, meta)
  end

  @doc """
  Creates a thinking signal.

  ## Parameters

  - `thought` - The content of the thinking step
  - `step` - The step number in the thinking process
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:thinking` with the provided thought and metadata including step.

  ## Examples

      iex> signal = LLMAgent.Signals.thinking("I need to get stock data", 1)
      iex> signal.type == :thinking and signal.data == "I need to get stock data"
      true
      iex> signal.meta.step
      1
  """
  def thinking(thought, step, meta \\ %{}) do
    Signal.new(:thinking, thought, Map.put(meta, :step, step))
  end

  @doc """
  Creates a tool call signal.

  ## Parameters

  - `name` - The name of the tool to call
  - `args` - The arguments for the tool call
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:tool_call` with the provided tool name, arguments, and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.tool_call("get_stock_price", %{ticker: "AAPL"})
      iex> signal.type == :tool_call
      true
      iex> signal.data.name == "get_stock_price" and signal.data.args.ticker == "AAPL"
      true
  """
  def tool_call(name, args, meta \\ %{}) do
    Signal.new(:tool_call, %{name: name, args: args}, meta)
  end

  @doc """
  Creates a tool result signal.

  ## Parameters

  - `name` - The name of the tool that was called
  - `result` - The result of the tool execution
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:tool_result` with the provided tool name, result, and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.tool_result("get_stock_price", %{price: 200.50})
      iex> signal.type == :tool_result
      true
      iex> signal.data.name == "get_stock_price" and signal.data.result.price == 200.50
      true
  """
  def tool_result(name, result, meta \\ %{}) do
    Signal.new(:tool_result, %{name: name, result: result}, meta)
  end

  @doc """
  Creates a response signal.

  ## Parameters

  - `content` - The content of the response
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:response` with the provided content and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.response("AAPL is trading at $200")
      iex> signal.type == :response and signal.data == "AAPL is trading at $200"
      true
  """
  def response(content, meta \\ %{}) do
    Signal.new(:response, content, meta)
  end

  @doc """
  Creates a task state signal.

  ## Parameters

  - `task_id` - The ID of the task
  - `state` - The current state of the task
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:task_state` with the provided task ID, state, and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.task_state("task_123", "running")
      iex> signal.type == :task_state
      true
      iex> signal.data.task_id == "task_123" and signal.data.state == "running"
      true
  """
  def task_state(task_id, state, meta \\ %{}) do
    Signal.new(:task_state, %{task_id: task_id, state: state}, meta)
  end

  @doc """
  Creates an error signal.

  ## Parameters

  - `message` - The error message
  - `source` - The source of the error
  - `meta` - Additional metadata for the signal

  ## Returns

  A signal of type `:error` with the provided message, source, and metadata.

  ## Examples

      iex> signal = LLMAgent.Signals.error("API unavailable", "get_stock_price")
      iex> signal.type == :error
      true
      iex> signal.data.message == "API unavailable" and signal.data.source == "get_stock_price"
      true
  """
  def error(message, source, meta \\ %{}) do
    Signal.new(:error, %{message: message, source: source}, meta)
  end
end
