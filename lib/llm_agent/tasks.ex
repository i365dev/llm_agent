defmodule LLMAgent.Tasks do
  @moduledoc """
  Manages long-running tasks using AgentForge's execution capabilities.

  This module provides functions for starting, monitoring, and controlling
  tasks that are implemented as sequences of AgentForge primitives, supporting
  complex flow patterns with branching, waiting conditions, and fine-grained
  state management.
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
        task_results: %{},
        task_stage: "initializing",
        task_checkpoints: [],
        recovery_points: []
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
          # Initialize task monitoring
          send(caller, {:task_update, task_id, "initializing", nil})

          # Execute with stage tracking
          {stage_results, intermediate_states} =
            collect_stage_results(task_flow, Signal.new(:start, params), task_state, timeout_ms)

          # Build final result with stage information
          result = %{
            stages: stage_results,
            final_result: List.last(stage_results)[:result],
            execution_time_ms: Enum.sum(Enum.map(stage_results, &(&1[:time_ms] || 0))),
            completed_stages: length(stage_results)
          }

          send(caller, {:task_complete, task_id, result, List.last(intermediate_states)})
        catch
          kind, error ->
            stack = __STACKTRACE__
            error_msg = Exception.format(kind, error, stack)

            error_data = %{
              error: error_msg,
              stage: task_state.task_stage,
              recoverable: recoverable_error?(error),
              recovery_points: task_state.recovery_points
            }

            send(caller, {:task_error, task_id, error_data})
        end
      end)

      # Return task ID and initial status signal
      {task_id, Signals.task_state(task_id, "running", %{async: true, stages: ["initializing"]})}
    else
      # Execute task synchronously with enhanced error handling and stage tracking
      case execute_task_with_stages(task_flow, Signal.new(:start, params), task_state, timeout_ms) do
        {:ok, result, stages, final_state} ->
          # Task completed successfully with stage information
          {:ok, task_id, %{result: result, stages: stages}, final_state}

        {:error, reason, stage, state} ->
          # Task failed with stage information
          {:error, task_id, %{error: reason, stage: stage}, state}
      end
    end
  end

  @doc """
  Gets the latest statistics for a task.

  ## Parameters

  - `task_id` - The ID of the task

  ## Returns

  A map of task statistics including stage information.
  """
  def get_stats(task_id) do
    # Get basic execution stats
    base_stats = AgentForge.Runtime.get_last_execution_stats()

    # Enhance with stage-specific information if available
    case :ets.lookup(:task_stats, task_id) do
      [{^task_id, stage_stats}] ->
        Map.merge(base_stats, %{
          stages: stage_stats,
          current_stage: List.last(stage_stats)[:name],
          stage_count: length(stage_stats)
        })

      [] ->
        base_stats
    end
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

  # Check if an error is recoverable based on its type
  defp recoverable_error?(_error) do
    # In a real implementation, would check error type
    # For now, return false
    false
  end

  # Collect results from each stage of task execution
  defp collect_stage_results(task_flow, signal, task_state, timeout_ms) do
    # Initialize collection of stage results
    {results, states} =
      execute_and_collect_stages(task_flow, signal, task_state, timeout_ms, [], [task_state])

    {Enum.reverse(results), Enum.reverse(states)}
  end

  # Recursively execute stages and collect results
  defp execute_and_collect_stages(_task_flow, _signal, state, _timeout_ms, results, states)
       when state.task_stage == "completed" do
    {results, states}
  end

  defp execute_and_collect_stages(task_flow, signal, state, timeout_ms, results, states) do
    # Update state with current stage
    current_stage = state.task_stage
    stage_start = System.monotonic_time(:millisecond)

    # Execute current stage
    case AgentForge.Runtime.execute_with_limits(
           task_flow,
           signal,
           initial_state: state,
           timeout_ms: timeout_ms
         ) do
      {:ok, result, new_state} ->
        # Calculate stage execution time
        stage_time = System.monotonic_time(:millisecond) - stage_start

        # Record stage result
        stage_result = %{
          name: current_stage,
          result: result,
          time_ms: stage_time,
          status: "completed"
        }

        # Determine next stage or completion
        next_state =
          if Map.get(new_state, :next_stage) do
            %{new_state | task_stage: new_state.next_stage}
          else
            %{new_state | task_stage: "completed"}
          end

        # Add checkpoint for recovery
        next_state =
          Map.update(
            next_state,
            :recovery_points,
            [current_stage],
            &[current_stage | &1]
          )

        # Continue to next stage or return final results
        execute_and_collect_stages(
          task_flow,
          Signal.new(:continue, result),
          next_state,
          timeout_ms,
          [stage_result | results],
          [next_state | states]
        )

      {:ok, result, new_state, _stats} ->
        # Similar to above but with stats
        # Calculate stage execution time
        stage_time = System.monotonic_time(:millisecond) - stage_start

        # Record stage result
        stage_result = %{
          name: current_stage,
          result: result,
          time_ms: stage_time,
          status: "completed"
        }

        # Determine next stage or completion
        next_state =
          if Map.get(new_state, :next_stage) do
            %{new_state | task_stage: new_state.next_stage}
          else
            %{new_state | task_stage: "completed"}
          end

        # Add checkpoint for recovery
        next_state =
          Map.update(
            next_state,
            :recovery_points,
            [current_stage],
            &[current_stage | &1]
          )

        # Continue to next stage or return final results
        execute_and_collect_stages(
          task_flow,
          Signal.new(:continue, result),
          next_state,
          timeout_ms,
          [stage_result | results],
          [next_state | states]
        )

      {:error, reason, error_state} ->
        # Record error result
        stage_time = System.monotonic_time(:millisecond) - stage_start

        error_result = %{
          name: current_stage,
          error: reason,
          time_ms: stage_time,
          status: "error"
        }

        # Mark state as error
        final_error_state = %{error_state | task_stage: "error"}

        # Return all results including error
        {[error_result | results], [final_error_state | states]}

      {:error, reason, error_state, _stats} ->
        # Record error result with stats
        stage_time = System.monotonic_time(:millisecond) - stage_start

        error_result = %{
          name: current_stage,
          error: reason,
          time_ms: stage_time,
          status: "error"
        }

        # Mark state as error
        final_error_state = %{error_state | task_stage: "error"}

        # Return all results including error
        {[error_result | results], [final_error_state | states]}
    end
  end

  defp execute_task_with_stages(task_flow, signal, task_state, timeout_ms) do
    # Similar to collect_stage_results but simpler for synchronous execution
    {results, states} = collect_stage_results(task_flow, signal, task_state, timeout_ms)
    final_result = List.last(results)
    final_state = List.last(states)

    case final_result[:status] do
      "completed" ->
        {:ok, final_result[:result], results, final_state}

      "error" ->
        {:error, final_result[:error], final_result[:name], final_state}
    end
  catch
    kind, error ->
      error_msg = Exception.format(kind, error, __STACKTRACE__)
      {:error, error_msg, task_state.task_stage, task_state}
  end
end
