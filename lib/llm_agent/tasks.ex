defmodule LLMAgent.Tasks do
  @moduledoc """
  Manages long-running tasks using AgentForge's execution capabilities.

  This module provides functions for starting, monitoring, and controlling
  tasks that are implemented as sequences of AgentForge primitives.
  """

  require Logger
  alias AgentForge.Signal
  alias LLMAgent.Signals

  @doc """
  Starts a task with the given definition and parameters.

  ## Parameters

  - `task_def` - The task definition as a list of AgentForge primitives
  - `params` - Parameters for the task
  - `state` - The current agent state
  - `opts` - Additional options for task execution

  ## Returns

  A tuple containing the task ID and a task state signal.

  ## Examples

      iex> task_def = [
      ...>   AgentForge.Primitives.transform(fn data -> Map.put(data, :processed, true) end)
      ...> ]
      iex> params = %{data: "test"}
      iex> state = %{}
      iex> {task_id, signal} = LLMAgent.Tasks.start(task_def, params, state)
      iex> is_binary(task_id) and signal.type == :task_state
      true
  """
  def start(task_def, params, state, opts \\ []) do
    # Create task ID
    task_id = "task_#{System.unique_integer([:positive, :monotonic])}"

    # Get timeout from options or use default
    # 5 minute default
    timeout_ms = Keyword.get(opts, :timeout_ms, 300_000)

    # Create task state with parameters
    task_state =
      Map.merge(state, %{
        task_id: task_id,
        task_params: params,
        task_state: "starting",
        task_results: %{}
      })

    # Get task flow from definition using LLMAgent.Flows
    task_flow = LLMAgent.Flows.task_flow(task_def, timeout_ms: timeout_ms)

    # Start task execution either synchronously or asynchronously
    async = Keyword.get(opts, :async, true)

    if async do
      # Start a process to execute the task asynchronously
      # and send updates back to the caller
      caller = self()

      Task.start(fn ->
        try do
          result = execute_task(task_flow, Signal.new(:start, params), task_state, timeout_ms)
          send(caller, {:task_complete, task_id, result})
        catch
          kind, error ->
            error_msg = Exception.format(kind, error, __STACKTRACE__)
            send(caller, {:task_error, task_id, error_msg})
        end
      end)

      # Return task ID and initial status signal
      {task_id, Signals.task_state(task_id, "running", %{async: true})}
    else
      # Execute task synchronously
      case execute_task(task_flow, Signal.new(:start, params), task_state, timeout_ms) do
        {:ok, result, task_state} ->
          # Task completed successfully
          {:ok, task_id, result, task_state}

        {:error, reason, task_state} ->
          # Task failed
          {:error, task_id, reason, task_state}
      end
    end
  end

  @doc """
  Gets the latest statistics for a task.

  ## Parameters

  - `_task_id` - The ID of the task

  ## Returns

  A map of task statistics.
  """
  def get_stats(_task_id) do
    # Leverage AgentForge's execution stats
    AgentForge.Runtime.get_last_execution_stats()
  end

  @doc """
  Attempts to cancel a running task.

  ## Parameters

  - `_task_id` - The ID of the task to cancel

  ## Returns

  - `:ok` - If the task was successfully cancelled
  - `{:error, reason}` - If the task could not be cancelled
  """
  def cancel(_task_id) do
    # In a real implementation, this would cancel the task
    # For now, just return ok
    :ok
  end

  @doc """
  Attempts to pause a running task.

  ## Parameters

  - `_task_id` - The ID of the task to pause

  ## Returns

  - `:ok` - If the task was successfully paused
  - `{:error, reason}` - If the task could not be paused
  """
  def pause(_task_id) do
    # In a real implementation, this would pause the task
    # For now, just return ok
    :ok
  end

  @doc """
  Attempts to resume a paused task.

  ## Parameters

  - `_task_id` - The ID of the task to resume

  ## Returns

  - `:ok` - If the task was successfully resumed
  - `{:error, reason}` - If the task could not be resumed
  """
  def resume(_task_id) do
    # In a real implementation, this would resume the task
    # For now, just return ok
    :ok
  end

  # Private functions

  defp execute_task(task_flow, signal, task_state, timeout_ms) do
    # Execute task with timeout
    result =
      AgentForge.Runtime.execute_with_limits(
        task_flow,
        signal,
        initial_state: task_state,
        timeout_ms: timeout_ms
      )

    case result do
      {:ok, result, task_state} ->
        {:ok, result, task_state}

      {:ok, result, task_state, _stats} ->
        # Handle case with execution stats
        {:ok, result, task_state}

      {:error, reason, task_state} ->
        {:error, reason, task_state}

      {:error, reason, task_state, _stats} ->
        # Handle case with execution stats
        {:error, reason, task_state}
    end
  end
end
