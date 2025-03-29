# Tool-using agent example
#
# This example demonstrates how to create an LLM-powered agent
# that can use tools to perform calculations and get the current time.
#
# Run with: elixir tool_using_agent.exs

# Import required modules
alias LLMAgent.{Signals, Store}

# Create a system prompt that defines the agent's behavior
system_prompt = """
You are a helpful assistant that can perform calculations and tell the current time.
When asked to perform calculations, use the calculator tool.
When asked about the time, use the current_time tool.
"""

# Create a demonstration module for a tool-using agent
defmodule LLMAgent.Examples.ToolDemo do
  @moduledoc """
  Demonstrates a tool-using agent with LLMAgent, showing how
  the agent can use tools to perform calculations and get the current time.
  """
  
  # Define tools the agent can use directly inside the module
  def tools do
    [
      %{
        name: "calculator",
        description: "Perform mathematical calculations. Requires an 'expression' parameter.",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "expression" => %{
              "type" => "string",
              "description" => "The mathematical expression to evaluate"
            }
          },
          "required" => ["expression"]
        },
        execute: fn args ->
          expr = Map.get(args, "expression", "0")
          
          try do
            {result, _} = Code.eval_string(expr)
            %{result: result}
          rescue
            e -> %{error: "Failed to evaluate expression: #{inspect(e)}"}
          end
        end
      },
      %{
        name: "current_time",
        description: "Get the current time and date.",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "format" => %{
              "type" => "string",
              "description" => "Optional format parameter, can be 'iso8601', 'utc', or 'unix'",
              "enum" => ["iso8601", "utc", "unix"]
            }
          }
        },
        execute: fn args -> 
          now = DateTime.utc_now()
          
          case Map.get(args, "format") do
            "iso8601" -> %{time: DateTime.to_iso8601(now), format: "ISO 8601"}
            "unix" -> %{time: DateTime.to_unix(now), format: "Unix timestamp"}
            _ -> %{
              utc_time: DateTime.to_string(now),
              iso8601: DateTime.to_iso8601(now),
              unix_timestamp: DateTime.to_unix(now)
            }
          end
        end
      }
    ]
  end
  
  @doc """
  Run the tool-using agent demo with several example questions
  """
  def run do
    IO.puts("\n=== Tool-Using Agent Example ===\n")
    
    # Example questions that require tool use
    questions = [
      "What's 42 * 73?",
      "What time is it right now?",
      "If I have 24 apples and give away 1/3 of them, how many do I have left?",
      "What's the current date and time in ISO 8601 format?"
    ]
    
    # Process each question and show response
    Enum.each(questions, &process_question/1)
    
    IO.puts("\n=== Example complete ===\n")
  end
  
  # Process a single question using the LLM agent
  defp process_question(question) do
    IO.puts("\nQuestion: #{question}")
    
    # In a real implementation, we would:
    # 1. Create a conversation flow with our system prompt and tools
    # {flow, initial_state} = LLMAgent.Flows.conversation(system_prompt, tools())
    # 
    # 2. Create a user message signal and add it to the state
    # user_message = Signals.user_message(question)
    # state = Store.add_message(initial_state, "user", question)
    #
    # 3. Run the agent (in real implementation would use LLMAgent.run which encapsulates AgentForge)
    # response = LLMAgent.run(flow, state)
    #
    # For this example, we'll show the API patterns but simulate LLM responses and tool calls
    mock_agent_interaction(question)
  end
  
  # Simulate agent interaction that would happen with actual LLM
  defp mock_agent_interaction(question) do
    # Simulate what the LLM would decide to do
    # In a real implementation, the LLM would return a signal that might indicate
    # thinking, tool usage, or a direct response
    
    cond do
      String.contains?(question, ["*", "+", "-", "/", "apples"]) ->
        # Simulate the agent deciding to use the calculator tool
        simulate_tool_usage("calculator", question)
        
      String.contains?(question, ["time", "date", "ISO"]) ->
        # Simulate the agent deciding to use the time tool
        simulate_tool_usage("current_time", question)
        
      true ->
        # Simulate the agent responding directly without tools
        response = %{
          type: :response,
          data: %{
            content: "I don't have the tools to answer that question effectively."
          }
        }
        display_response(response)
    end
  end
  
  # Simulate the agent deciding to call a tool
  defp simulate_tool_usage(tool_name, question) do
    # In a real implementation, this would be a signal flow:
    # 1. The LLM generates a tool_call signal
    # 2. The handler processes the tool call
    # 3. The tool result is added to the state
    # 4. The LLM generates a final response based on the tool result
    
    case tool_name do
      "calculator" ->
        # Simulate the LLM generating a tool call for calculator
        IO.puts("[AGENT THINKING]: I need to use the calculator tool to solve this.")
        
        # Extract expression from question (this is what the LLM would do)
        expression = cond do
          String.contains?(question, "42 * 73") -> "42 * 73"
          String.contains?(question, "24 apples") -> "24 - (24 / 3)"
          true -> "0"
        end
        
        # Simulate generating a tool_call signal (in real implementation, this would be done by LLM)
        tool_call_signal = %{
          type: :tool_call,
          data: %{
            tool: "calculator",
            arguments: %{"expression" => expression}
          }
        }
        IO.puts("[TOOL CALL]: #{tool_call_signal.data.tool}(#{expression})")
        
        # Execute the tool (this is what the handler would do)
        calculator = Enum.find(tools(), fn t -> t.name == "calculator" end)
        result = calculator.execute.(%{"expression" => expression})
        
        # Simulate adding the function result to state (handled by LLMAgent.Store)
        # state = Store.add_function_result(state, "calculator", inspect(result))
        
        # Simulate the LLM generating a final response based on tool result
        response = %{
          type: :response,
          data: %{
            content: if String.contains?(question, "apples") do
              "I used the calculator to figure this out. If you have 24 apples and give away 1/3 of them,"
              <> " you'd be giving away 8 apples. That leaves you with #{result.result} apples."
            else
              "I calculated that #{expression} = #{result.result}."
            end
          }
        }
        display_response(response)
        
      "current_time" ->
        # Simulate the LLM generating a tool call for current_time
        IO.puts("[AGENT THINKING]: I should use the current_time tool for this.")
        
        # Determine what format is requested (simulating LLM reasoning)
        format = if String.contains?(question, "ISO"), do: "iso8601", else: "utc"
        
        # Simulate generating a tool_call signal
        tool_call_signal = %{
          type: :tool_call,
          data: %{
            tool: "current_time",
            arguments: (if format == "iso8601", do: %{"format" => "iso8601"}, else: %{})
          }
        }
        IO.puts("[TOOL CALL]: #{tool_call_signal.data.tool}(#{inspect(tool_call_signal.data.arguments)})")
        
        # Execute the tool
        time_tool = Enum.find(tools(), fn t -> t.name == "current_time" end)
        time_data = time_tool.execute.(tool_call_signal.data.arguments)
        
        # Simulate the LLM generating a final response based on tool result
        response = %{
          type: :response,
          data: %{
            content: if String.contains?(question, "ISO") do
              "According to my current_time tool, the current date and time in ISO 8601 format is #{time_data.time}."
            else
              "The current time is #{time_data.utc_time} (UTC)."
            end
          }
        }
        display_response(response)
    end
  end
  
  # Display the response from the LLM
  defp display_response(%{type: :response} = signal) do
    IO.puts("Answer: #{signal.data.content}")
  end
  
  defp display_response(%{type: :error} = signal) do
    IO.puts("Error occurred: #{inspect(signal.data)}")
  end
  
  defp display_response(other_signal) do
    IO.puts("Unexpected signal: #{inspect(other_signal)}")
  end
end

# Run the tool-using agent example
LLMAgent.Examples.ToolDemo.run()
