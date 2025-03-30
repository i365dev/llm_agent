defmodule LLMAgent.FlowsTest do
  @moduledoc """
  Tests for the LLMAgent.Flows module.
  Verifies flow composition and behavior.
  """

  use ExUnit.Case

  alias LLMAgent.{Flows, Signals, Store}

  setup do
    store_name = String.to_atom("flow_test_#{System.unique_integer([:positive])}")
    store = Store.start_link(name: store_name)

    on_exit(fn ->
      if pid = Process.whereis(store_name) do
        Process.exit(pid, :normal)
      end
    end)

    %{store_name: store_name}
  end

  describe "conversation/3" do
    test "creates a conversation flow with store initialization", %{store_name: store_name} do
      # Setup
      system_prompt = "You are a helpful assistant"
      tools = [%{name: "calculator", description: "Performs calculations"}]
      options = [store_name: store_name]

      # Create conversation flow
      {flow, initial_state} = Flows.conversation(system_prompt, tools, options)

      # Verify flow is a function
      assert is_function(flow, 2)

      # Verify state has correct configuration
      assert Map.has_key?(initial_state, :store_name)
      assert initial_state.store_name == store_name
      assert Map.has_key?(initial_state, :available_tools)
      assert initial_state.available_tools == tools

      # Verify system prompt was stored
      history = Store.get_llm_history(store_name)
      assert [%{role: "system", content: ^system_prompt}] = history
    end

    test "handles conversation with tools", %{store_name: store_name} do
      system_prompt = "You are a calculator assistant"

      tools = [
        %{
          name: "calculator",
          description: "Performs calculations",
          execute: fn %{"expression" => expr} ->
            {result, _} = Code.eval_string(expr)
            %{result: result}
          end
        }
      ]

      options = [store_name: store_name]

      {flow, state} = Flows.conversation(system_prompt, tools, options)

      # Verify tool configuration
      assert length(state.available_tools) == 1
      [tool] = state.available_tools
      assert tool.name == "calculator"

      # Verify tool registry initialization
      assert is_function(state.tool_registry, 1)
    end
  end

  describe "task_flow/2" do
    test "processes tasks with state management", %{store_name: store_name} do
      # Setup a task that uses Store
      task_handler = fn _signal, state ->
        Store.add_message(store_name, "system", "Processing task")
        result = "Task completed"
        {:ok, result, state}
      end

      task_definition = [task_handler]
      options = [store_name: store_name]

      # Create flow
      flow = Flows.task_flow(task_definition, options)

      # Verify flow
      assert is_function(flow, 2)

      # Test flow execution with signal
      signal = Signals.user_message("Start task")
      state = %{store_name: store_name}
      {result, _new_state} = flow.(signal, state)

      # Verify task execution was recorded
      history = Store.get_llm_history(store_name)
      assert Enum.any?(history, &(&1.role == "system" and &1.content == "Processing task"))

      # Verify result
      assert match?({{:emit, _}, _}, result)
    end
  end

  describe "batch_processing/3" do
    test "processes batch with store updates", %{store_name: store_name} do
      # Setup batch items
      items = ["item1", "item2"]

      # Setup handler that uses Store
      batch_handler = fn signal, state ->
        current_item = Map.get(state, :current_item)
        Store.add_message(store_name, "system", "Processing: #{current_item}")
        {{:emit, signal}, state}
      end

      options = [store_name: store_name]

      # Create flow
      flow = Flows.batch_processing(items, batch_handler, options)

      # Execute flow
      signal = Signals.user_message("Process batch")
      state = %{store_name: store_name}
      {result, _final_state} = flow.(signal, state)

      # Verify processing was recorded
      history = Store.get_llm_history(store_name)
      assert Enum.any?(history, &String.contains?(&1.content, "Processing:"))

      # Verify result
      assert match?({{:emit, _}, _}, result)
    end

    test "handles empty batch gracefully", %{store_name: store_name} do
      items = []
      batch_handler = fn _signal, state -> {{:emit, "done"}, state} end
      options = [store_name: store_name]

      flow = Flows.batch_processing(items, batch_handler, options)

      signal = Signals.user_message("Process empty batch")
      state = %{store_name: store_name}
      {result, _final_state} = flow.(signal, state)

      assert match?({{:halt, _}, _}, result)
    end
  end

  describe "qa_agent/2" do
    test "creates qa agent with store", %{store_name: store_name} do
      system_prompt = "You are a QA assistant"
      options = [store_name: store_name]

      {flow, state} = Flows.qa_agent(system_prompt, options)

      # Verify flow creation
      assert is_function(flow, 2)
      assert state.store_name == store_name

      # Verify system prompt was stored
      history = Store.get_llm_history(store_name)
      assert [%{role: "system", content: ^system_prompt}] = history
    end
  end

  describe "tool_agent/3" do
    test "creates tool agent with store", %{store_name: store_name} do
      system_prompt = "You are a tool-using assistant"

      tools = [
        %{
          name: "test_tool",
          description: "A test tool",
          execute: fn _args -> %{result: "test"} end
        }
      ]

      options = [store_name: store_name]

      {flow, state} = Flows.tool_agent(system_prompt, tools, options)

      # Verify flow creation
      assert is_function(flow, 2)
      assert state.store_name == store_name
      assert length(state.available_tools) == 1

      # Verify system prompt and tool setup
      history = Store.get_llm_history(store_name)
      assert [%{role: "system", content: ^system_prompt}] = history
    end
  end
end
