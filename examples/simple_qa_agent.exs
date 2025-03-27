# A simple question-answering agent example
#
# This example demonstrates how to create a basic LLM-powered
# question-answering agent without tools.
#
# Run with: elixir simple_qa_agent.exs

# Import required modules
alias LLMAgent.{Signals, Store}

# Create a system prompt that defines the agent's behavior
system_prompt = """
You are a helpful assistant that specializes in explaining Elixir concepts.
Your answers should be clear, concise, and accurate.
"""

# Create the agent flow and initial state
{flow, initial_state} = LLMAgent.Flows.qa_agent(system_prompt)

# Example user questions
questions = [
  "What is Elixir?",
  "How do processes work in Elixir?",
  "What's the difference between map and reduce in Elixir?"
]

# Process each question
Enum.reduce(questions, initial_state, fn question, state ->
  # Create a user message signal
  user_signal = Signals.user_message(question)
  
  IO.puts("\nQuestion: #{question}")
  
  # Process the signal through the flow
  case AgentForge.process(flow, state, user_signal) do
    {:ok, %{type: :response, data: response}, new_state} ->
      IO.puts("Answer: #{response}")
      # Return the updated state for the next question
      new_state
      
    {:error, reason, state} ->
      IO.puts("Error: #{inspect(reason)}")
      state
  end
end)
