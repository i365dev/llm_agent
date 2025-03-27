# Tool-using agent example
#
# This example demonstrates how to create an LLM-powered agent
# that can use tools to perform calculations and get the current time.
#
# Run with: elixir tool_using_agent.exs

# Import required modules
alias LLMAgent.{Signals, Store}

# Define tools the agent can use
tools = [
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

# Create a system prompt that defines the agent's behavior
system_prompt = """
You are a helpful assistant that can perform calculations and tell the current time.
When asked to perform calculations, use the calculator tool.
When asked about the time, use the current_time tool.
"""

# Create the agent flow and initial state
{flow, initial_state} = LLMAgent.Flows.conversation(system_prompt, tools)

# Example user questions that require tools
questions = [
  "What's 42 * 73?",
  "What time is it right now?",
  "If I have 24 apples and give away 1/3 of them, how many do I have left?",
  "What's the current date and time in ISO 8601 format?"
]

# Process each question
Enum.reduce(questions, initial_state, fn question, state ->
  # Create a user message signal
  user_signal = Signals.user_message(question)
  
  IO.puts("\nQuestion: #{question}")
  
  # Process the signal through the flow
  result = AgentForge.process(flow, state, user_signal)
  
  case result do
    {:ok, %{type: :response, data: response}, new_state} ->
      IO.puts("Answer: #{response}")
      # Return the updated state for the next question
      new_state
      
    {:error, reason, state} ->
      IO.puts("Error: #{inspect(reason)}")
      state
  end
end)
