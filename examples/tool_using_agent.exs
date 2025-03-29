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
        execute: fn args ->
          expr = Map.get(args, "expression", "0")
          {result, _} = Code.eval_string(expr)
          %{result: result}
        end
      },
      %{
        name: "current_time",
        description: "Get the current time and date.",
        execute: fn _args -> 
          now = DateTime.utc_now()
          %{
            utc_time: DateTime.to_string(now),
            iso8601: DateTime.to_iso8601(now),
            unix_timestamp: DateTime.to_unix(now)
          }
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
  
  # Process a single question and display result
  defp process_question(question) do
    IO.puts("\nQuestion: #{question}")
    
    # For this example, we'll simulate the LLM deciding which tool to use
    # based on pattern matching the question
    cond do
      String.contains?(question, ["*", "+", "-", "/", "apples"]) ->
        # For calculation questions, use the calculator tool
        use_calculator_tool(question)
        
      String.contains?(question, ["time", "date", "ISO"]) ->
        # For time-related questions, use the current_time tool
        use_time_tool(question)
        
      true ->
        # Fallback for unknown questions
        IO.puts("Answer: I don't know how to answer that question using my available tools.")
    end
  end
  
  # Simulate using the calculator tool
  defp use_calculator_tool(question) do
    # Extract expression from question (simplified for demo)
    expression = cond do
      String.contains?(question, "42 * 73") -> "42 * 73"
      String.contains?(question, "24 apples") -> "24 - (24 / 3)"
      true -> "0"
    end
    
    # Call the actual calculator tool function from our tools list
    calculator = Enum.find(tools(), fn t -> t.name == "calculator" end)
    result = calculator.execute.(%{"expression" => expression})
    
    # Format answer based on the question
    answer = cond do
      String.contains?(question, "apples") ->
        "If you give away 1/3 of 24 apples, you have #{result.result} apples left."
      true ->
        "The result of #{expression} is #{result.result}."
    end
    
    IO.puts("Answer: #{answer}")
  end
  
  # Simulate using the time tool
  defp use_time_tool(question) do
    # Call the actual time tool function from our tools list
    time_tool = Enum.find(tools(), fn t -> t.name == "current_time" end)
    time_data = time_tool.execute.(%{})
    
    # Format answer based on the question
    answer = cond do
      String.contains?(question, "ISO") ->
        "The current date and time in ISO 8601 format is #{time_data.iso8601}."
      true ->
        "The current time is #{time_data.utc_time} (UTC)."
    end
    
    IO.puts("Answer: #{answer}")
  end
end

# Run the tool-using agent example
LLMAgent.Examples.ToolDemo.run()
