defmodule LLMAgent.Handlers do
  @moduledoc """
  Provides standard handlers for processing LLM-specific signals.

  This module implements signal handlers for the various LLM agent signal types,
  following AgentForge's handler pattern. Each handler takes a signal and state,
  processes the signal, and returns a tuple with a result and a new state.
  """

  require Logger

  alias LLMAgent.{Signals, Store}

  # Get store name from state or use default
  defp get_store_name(state) do
    Map.get(state, :store_name, LLMAgent.Store)
  end

  @doc """
  Handles user message signals.
  """
  def message_handler(%{type: :user_message} = signal, state) do
    Logger.info("Processing user message: #{inspect(signal.data)}")
    store_name = get_store_name(state)

    # Store the user message in history
    Store.add_message(store_name, "user", signal.data)

    # Get provider and tools configuration
    provider = Map.get(state, :provider, :openai)
    tools = Map.get(state, :available_tools, [])

    # Get conversation history from Store
    history = Store.get_llm_history(store_name)

    # Call LLM with updated context
    try do
      llm_result =
        LLMAgent.Plugin.call_llm(%{
          "provider" => provider,
          "messages" => history,
          "tools" => tools,
          "options" => Map.get(state, :llm_options, %{})
        })

      cond do
        has_tool_calls?(llm_result) ->
          tool_calls = extract_tool_calls(llm_result)
          [first_tool | _rest] = tool_calls

          tool_data = %{
            name: first_tool.name,
            args: first_tool.arguments
          }

          {{:emit, Signals.tool_call(tool_data.name, tool_data.args)}, state}

        contains_thinking_marker?(llm_result) ->
          thought = extract_content(llm_result)
          Store.add_thought(store_name, thought)
          {{:emit, Signals.thinking(thought, 1)}, state}

        true ->
          content = extract_content(llm_result)
          Store.add_message(store_name, "assistant", content)
          {{:emit, Signals.response(content)}, state}
      end
    rescue
      error ->
        Logger.error("Error in message handler: #{inspect(error)}")
        {{:emit, Signals.error("LLM processing failed: #{inspect(error)}", "llm_call")}, state}
    end
  end

  def message_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles thinking step signals.
  """
  def thinking_handler(%{type: :thinking} = signal, state) do
    Logger.info("Processing thinking step: #{inspect(signal.data)}")
    store_name = get_store_name(state)

    # Get current step and thought
    step = signal.meta.step
    thought = signal.data

    # Add thought if not already present
    Store.add_thought(store_name, thought)

    # Get history and tools
    history = Store.get_llm_history(store_name)
    tools = Map.get(state, :available_tools, [])
    provider = Map.get(state, :provider, :openai)

    try do
      llm_result =
        LLMAgent.Plugin.call_llm(%{
          "provider" => provider,
          "messages" => format_history_with_thought(history, thought),
          "tools" => tools,
          "options" => Map.get(state, :llm_options, %{})
        })

      cond do
        has_tool_calls?(llm_result) ->
          tool_calls = extract_tool_calls(llm_result)
          [first_tool | _rest] = tool_calls

          tool_data = %{
            name: first_tool.name,
            args: first_tool.arguments
          }

          {{:emit, Signals.tool_call(tool_data.name, tool_data.args)}, state}

        should_continue_thinking?(llm_result, step) ->
          next_thought = extract_content(llm_result)
          Store.add_thought(store_name, next_thought)
          {{:emit, Signals.thinking(next_thought, step + 1)}, state}

        true ->
          content = extract_content(llm_result)
          Store.add_message(store_name, "assistant", content)
          {{:emit, Signals.response(content)}, state}
      end
    rescue
      error ->
        Logger.error("Error in thinking handler: #{inspect(error)}")
        {{:emit, Signals.error("LLM processing failed: #{inspect(error)}", "thinking")}, state}
    end
  end

  def thinking_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles tool call signals.
  """
  def tool_handler(%{type: :tool_call} = signal, state) do
    store_name = get_store_name(state)
    tool_name = signal.data.name
    tool_args = signal.data.args

    Logger.info("Tool call: #{tool_name} with args: #{inspect(tool_args)}")

    tool_registry = Map.get(state, :tool_registry, &AgentForge.Tools.get/1)

    case tool_registry.(tool_name) do
      {:ok, tool_fn} when is_function(tool_fn) ->
        try do
          result = tool_fn.(tool_args)
          Store.add_tool_call(store_name, tool_name, tool_args, result)
          {{:emit, Signals.tool_result(tool_name, result)}, state}
        rescue
          e ->
            error_message = Exception.message(e)
            Store.add_tool_call(store_name, tool_name, tool_args, %{error: error_message})
            {{:emit, Signals.error(error_message, tool_name)}, state}
        end

      {:error, reason} ->
        error_message = "Tool not found: #{reason}"
        Logger.warning(error_message)
        Store.add_tool_call(store_name, tool_name, tool_args, %{error: error_message})
        {{:emit, Signals.error(error_message, tool_name)}, state}
    end
  end

  def tool_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles tool result signals.
  """
  def tool_result_handler(%{type: :tool_result} = signal, state) do
    store_name = get_store_name(state)
    Logger.info("Processing tool result: #{inspect(signal.data)}")

    tool_name = signal.data.name
    tool_result = signal.data.result

    # Get history from Store
    history = Store.get_llm_history(store_name)
    tools = Map.get(state, :available_tools, [])

    # Add function result to Store
    Store.add_function_result(store_name, tool_name, tool_result)

    try do
      provider = Map.get(state, :provider, :openai)
      formatted_history = format_history_with_tool_result(history, tool_name, tool_result)

      llm_result =
        LLMAgent.Plugin.call_llm(%{
          "provider" => provider,
          "messages" => formatted_history,
          "tools" => tools,
          "options" => Map.get(state, :llm_options, %{})
        })

      cond do
        has_tool_calls?(llm_result) ->
          tool_calls = extract_tool_calls(llm_result)
          [first_tool | _rest] = tool_calls
          {{:emit, Signals.tool_call(first_tool.name, first_tool.arguments)}, state}

        should_continue_thinking?(llm_result, 1) ->
          next_thought = extract_content(llm_result)
          Store.add_thought(store_name, next_thought)
          {{:emit, Signals.thinking(next_thought, 2)}, state}

        true ->
          content = extract_content(llm_result)
          Store.add_message(store_name, "assistant", content)
          {{:emit, Signals.response(content)}, state}
      end
    rescue
      error ->
        Logger.error("Error in tool result handler: #{inspect(error)}")
        error_meta = %{source: "tool_result", tool: tool_name}
        {{:emit, Signals.error("LLM processing failed: #{inspect(error)}", error_meta)}, state}
    end
  end

  def tool_result_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles task state signals.
  """
  def task_handler(%{type: :task_state} = signal, state) do
    store_name = get_store_name(state)
    task_id = signal.data.task_id
    task_state = signal.data.state

    # Update task state in Store
    Store.update_task_state(store_name, task_id, task_state)
    {:skip, state}
  end

  def task_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles response signals.
  """
  def response_handler(%{type: :response} = signal, state) do
    formatter = Map.get(state, :response_formatter)

    formatted_response =
      if is_function(formatter, 1) do
        formatter.(signal.data)
      else
        signal.data
      end

    {{:halt, Signals.response(formatted_response)}, state}
  end

  def response_handler(_signal, state), do: {:skip, state}

  @doc """
  Handles error signals.
  """
  def error_handler(%{type: :error} = signal, state) do
    store_name = get_store_name(state)
    message = signal.data.message
    source = signal.data.source

    Logger.error("LLMAgent error in #{source}: #{message}\nSignal: #{inspect(signal)}")

    {response, error_type} =
      case source do
        "llm_call" ->
          {"I'm sorry, I'm having trouble processing your request: #{message}", :llm_error}

        "tool_call" ->
          {"I tried to use a tool but encountered an error: #{message}", :tool_error}

        "tool_result" ->
          {"I received a tool result but encountered an error: #{message}", :tool_result_error}

        _ ->
          {"An error occurred: #{message}", :generic_error}
      end

    # Add error and response to store
    Store.add_error(store_name, {error_type, message, DateTime.utc_now()})
    Store.add_message(store_name, "assistant", response)

    {{:emit, Signals.response(response)}, state}
  end

  def error_handler(_signal, state), do: {:skip, state}

  # Helper functions for LLM processing (unchanged)
  defp format_history_with_thought(history, thought) do
    thought_message = %{"role" => "system", "content" => "Current thinking step: #{thought}"}
    history ++ [thought_message]
  end

  defp format_history_with_tool_result(history, tool_name, tool_result) do
    formatted_result = Jason.encode!(tool_result, pretty: true)

    function_result_message = %{
      "role" => "function",
      "name" => tool_name,
      "content" => formatted_result
    }

    guidance_message = %{
      "role" => "system",
      "content" =>
        "You received a result from the #{tool_name} function. Use this information to continue the conversation."
    }

    history ++ [function_result_message, guidance_message]
  end

  defp has_tool_calls?(llm_result) do
    case llm_result do
      %{"tool_calls" => tool_calls} when is_list(tool_calls) and length(tool_calls) > 0 -> true
      _ -> false
    end
  end

  defp contains_thinking_marker?(llm_result) do
    content = extract_content(llm_result)

    cond do
      is_nil(content) -> false
      String.contains?(content, "I need to think") -> true
      String.contains?(content, "Let me think") -> true
      String.contains?(content, "Thinking:") -> true
      String.match?(content, ~r/^Step \d+:/i) -> true
      String.match?(content, ~r/^Thinking step \d+:/i) -> true
      true -> false
    end
  end

  defp should_continue_thinking?(llm_result, current_step) do
    content = extract_content(llm_result)

    if is_nil(content) do
      false
    else
      contains_thinking_phrases?(content) or
        matches_step_pattern?(content, current_step) or
        numbered_list_thinking?(content) or
        starts_with_continuation_phrase?(content)
    end
  end

  defp contains_thinking_phrases?(content) do
    String.contains?(content, "I need to continue thinking") or
      String.contains?(content, "Let me continue")
  end

  defp matches_step_pattern?(content, current_step) do
    String.match?(content, ~r/^Step #{current_step + 1}:/i) or
      String.match?(content, ~r/^Thinking step #{current_step + 1}:/i)
  end

  defp numbered_list_thinking?(content) do
    String.match?(content, ~r/^\d+\. /) and not String.contains?(content, "final answer")
  end

  defp starts_with_continuation_phrase?(content) do
    String.match?(content, ~r/^Next, I/i) or
      String.match?(content, ~r/^Now I need to/i)
  end

  defp extract_content(llm_result) do
    case llm_result do
      %{"content" => content} when is_binary(content) ->
        content

      %{"message" => %{"content" => content}} when is_binary(content) ->
        content

      %{"choices" => [%{"message" => %{"content" => content}} | _]} when is_binary(content) ->
        content

      %{"choices" => [%{"text" => content} | _]} when is_binary(content) ->
        content

      %{"choices" => [first | _]} ->
        get_in(first, ["message", "content"]) || ""

      _ ->
        ""
    end
  end

  defp extract_tool_calls(llm_result) do
    case llm_result do
      %{"tool_calls" => tool_calls} when is_list(tool_calls) ->
        parse_tool_calls(tool_calls)

      %{"choices" => [%{"message" => %{"tool_calls" => tool_calls}} | _]}
      when is_list(tool_calls) ->
        parse_tool_calls(tool_calls)

      _ ->
        []
    end
  end

  defp parse_tool_calls(tool_calls) do
    Enum.map(tool_calls, &parse_single_tool_call/1)
  end

  defp parse_single_tool_call(tool_call) do
    args_json = get_in(tool_call, ["function", "arguments"]) || "{}"
    name = get_in(tool_call, ["function", "name"]) || ""

    %{
      name: name,
      arguments: parse_arguments(args_json)
    }
  end

  defp parse_arguments(args_json) do
    case Jason.decode(args_json) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end
end
