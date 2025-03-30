# Simple Question-Answering Agent Example
#
# This example demonstrates how to create a basic LLM-powered
# question-answering agent using LLMAgent framework.
#
# Key concepts demonstrated:
# 1. Configuring a mock LLM provider for testing
# 2. Creating a simple QA agent with system prompt
# 3. Handling conversations and responses
# 4. Error handling and state management
#
# Run with: elixir simple_qa_agent.exs

# First, let's define a mock LLM provider for testing
defmodule MockElixirQAProvider do
  @behaviour LLMAgent.Provider

  @impl true
  def generate_response(messages, _opts \\ []) do
    # Get the last user message
    last_message =
      messages
      |> Enum.reverse()
      |> Enum.find(fn msg -> msg["role"] == "user" end)

    question = last_message["content"]

    # Simulate LLM response format
    response =
      case String.downcase(question) do
        q when String.contains?(q, "elixir") and String.contains?(q, "what is") ->
          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     "Elixir is a dynamic, functional programming language designed for building scalable and maintainable applications. It runs on the BEAM (Erlang's virtual machine) and excels at handling concurrency, fault tolerance, and distributed computing.",
                   "role" => "assistant"
                 }
               }
             ]
           }}

        q when String.contains?(q, "process") ->
          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     "Elixir processes are lightweight units of concurrency managed by the BEAM VM. They're isolated, communicate through message passing, and can be created in large numbers (millions) due to their efficiency. They're fundamental to Elixir's actor-based concurrency model.",
                   "role" => "assistant"
                 }
               }
             ]
           }}

        q when String.contains?(q, "error") ->
          {:error, "Simulated LLM error for testing error handling"}

        _ ->
          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" => "I'll explain this in the context of Elixir: #{question}",
                   "role" => "assistant"
                 }
               }
             ]
           }}
      end

    # Add some latency to simulate real API calls
    Process.sleep(100)
    response
  end
end

defmodule LLMAgent.Examples.SimpleQA do
  @moduledoc """
  Demonstrates a simple question-answering agent built with LLMAgent.
  Shows proper error handling and conversation management.
  """

  alias LLMAgent.{Flows, Signals, Store}

  def run do
    # 1. Configure LLMAgent to use our mock provider
    Application.put_env(:llm_agent, :provider, MockElixirQAProvider)

    # 2. Create store for this example
    store_name = :elixir_qa_store
    _store = Store.start_link(name: store_name)

    # 3. Create system prompt that defines the agent's behavior
    system_prompt = """
    You are a helpful assistant that specializes in explaining Elixir concepts.
    Your answers should be clear, concise, and accurate.
    When giving code examples, use proper Elixir syntax.
    """

    # 4. Create conversation flow
    {flow, state} = Flows.qa_agent(system_prompt, store_name: store_name)

    IO.puts("\n=== Simple Question-Answering Agent Example ===\n")
    IO.puts("This example demonstrates:")
    IO.puts("- Using LLMAgent with a mock LLM provider")
    IO.puts("- Proper conversation flow and state management")
    IO.puts("- Error handling and response processing\n")

    # 5. Process example questions
    questions = [
      "What is Elixir?",
      "How do processes work in Elixir?",
      # Will demonstrate error handling
      "trigger an error",
      "What's special about pattern matching?"
    ]

    # Process each question
    Enum.each(questions, fn question ->
      IO.puts("\nQuestion: #{question}")

      # Create user message signal
      signal = Signals.user_message(question)

      # Process the message through the flow
      case LLMAgent.process(flow, signal, state) do
        {:ok, response, _new_state} ->
          # Display the response
          display_response(response)

        {:error, error, _state} ->
          # Display error
          IO.puts("Error: #{error}")
      end
    end)

    # 6. Show conversation history from Store
    IO.puts("\n=== Conversation History ===")
    history = Store.get_llm_history(store_name)

    Enum.each(history, fn message ->
      case message do
        %{role: "system"} ->
          IO.puts("System: #{message.content}")

        %{role: "user"} ->
          IO.puts("\nHuman: #{message.content}")

        %{role: "assistant"} ->
          IO.puts("Assistant: #{message.content}")

        _ ->
          IO.puts("#{String.capitalize(message.role)}: #{message.content}")
      end
    end)

    IO.puts("\n=== Example Complete ===")

    IO.puts("""

    To use this in your own application:

    1. Configure your LLM provider:
       Application.put_env(:llm_agent, :provider, LLMAgent.Providers.OpenAI)
       Application.put_env(:llm_agent, :api_key, System.get_env("OPENAI_API_KEY"))

    2. Initialize store and create QA agent:
       store_name = MyApp.ConversationStore
       Store.start_link(name: store_name)
       {flow, state} = LLMAgent.Flows.qa_agent(system_prompt, store_name: store_name)

    3. Process messages:
       {:ok, response} = LLMAgent.process(flow, Signals.user_message(question), state)

    4. Handle responses:
       case response do
         %{type: :response} -> handle_response(response.data)
         %{type: :error} -> handle_error(response.data)
       end

    5. Get conversation history:
       history = LLMAgent.Store.get_llm_history(store_name)
    """)
  end

  # Display different types of responses
  defp display_response(%{type: :response} = signal) do
    IO.puts("Assistant: #{signal.data}")
  end

  defp display_response(%{type: :error} = signal) do
    IO.puts("Error: #{signal.data.message}")
  end

  defp display_response(other) do
    IO.puts("Unexpected response: #{inspect(other)}")
  end
end

# Run the example
LLMAgent.Examples.SimpleQA.run()
