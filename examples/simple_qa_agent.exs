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

# Create demo module to show question-answering capabilities
defmodule LLMAgent.Examples.SimpleQA do
  @moduledoc """
  Demonstrates a simple question-answering agent built with LLMAgent.
  """
  
  @doc """
  Run the QA agent demo with several example questions
  """
  def run do
    IO.puts("\n=== Simple Question-Answering Agent Example ===\n")
    
    # Example questions to process
    questions = [
      "What is Elixir?",
      "How do processes work in Elixir?", 
      "What's the difference between map and reduce in Elixir?"
    ]
    
    # Process each question and show response
    Enum.each(questions, &process_question/1)
    
    IO.puts("\n=== Example complete ===\n")
  end
  
  # Process a single question and display result
  defp process_question(question) do
    IO.puts("\nQuestion: #{question}")
    
    # In a real application, we would use the LLMAgent.Flows API:
    # {flow, initial_state} = LLMAgent.Flows.qa_agent(system_prompt)
    # And then run the flow with AgentForge
    
    # For the example, we'll just simulate a response
    generate_simulated_response(question)
  end
  
  # Simulate LLM response for the example
  defp generate_simulated_response(question) do
    response = case question do
      "What is Elixir?" ->
        "Elixir is a functional, concurrent programming language built on the Erlang VM (BEAM). "
        <> "It combines the functional paradigm with a syntax inspired by Ruby, making it both "
        <> "powerful and pleasant to work with. Elixir excels at building scalable, fault-tolerant "
        <> "applications, especially for distributed systems."
        
      "How do processes work in Elixir?" ->
        "In Elixir, processes are lightweight units of concurrency managed by the BEAM VM, not OS processes. "
        <> "They communicate via message passing, are isolated from each other (sharing no memory), "
        <> "and are extremely lightweight (can create millions). This actor-based concurrency model "
        <> "helps build fault-tolerant systems through supervision trees, where processes can monitor "
        <> "and restart other processes when they fail."
        
      _ ->
        "Map transforms each element in a collection by applying a function to it, returning a collection "
        <> "of the same size. Reduce (or fold) combines all elements into a single accumulated value. "
        <> "Map returns a new collection with transformed elements. Reduce returns a single value. "
        <> "In Elixir: `Enum.map([1,2,3], &(&1*2))` returns `[2,4,6]`, while "
        <> "`Enum.reduce([1,2,3], 0, &(&1+&2))` returns `6`."
    end
    
    IO.puts("Answer: #{response}")
  end
end

# Run the QA agent example
LLMAgent.Examples.SimpleQA.run()
