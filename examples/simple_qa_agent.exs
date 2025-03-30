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
# Run with: mix run examples/simple_qa_agent.exs

# First, let's define a mock LLM provider for testing
defmodule MockElixirQAProvider do
  def generate_response(messages, _opts \\ []) do
    # Extract the last user message from various possible message formats
    last_message =
      cond do
        # If messages use atom keys format: %{role: "user", content: "..."}
        Enum.any?(messages, fn msg -> is_map(msg) and Map.has_key?(msg, :role) end) ->
          messages
          |> Enum.reverse()
          |> Enum.find(fn msg -> msg[:role] == "user" end)
          |> case do
            nil -> %{content: ""}
            msg -> %{content: msg[:content] || ""}
          end

        # If messages use string keys format: %{"role" => "user", "content" => "..."}
        Enum.any?(messages, fn msg -> is_map(msg) and Map.has_key?(msg, "role") end) ->
          messages
          |> Enum.reverse()
          |> Enum.find(fn msg -> msg["role"] == "user" end)
          |> case do
            nil -> %{content: ""}
            msg -> %{content: msg["content"] || ""}
          end

        # For other formats, try basic string extraction
        true ->
          last_user_message =
            messages
            |> Enum.reverse()
            |> Enum.find(fn msg ->
              is_binary(msg) or
                (is_map(msg) and
                   Map.values(msg)
                   |> Enum.any?(fn v -> is_binary(v) and String.contains?(v, "?") end))
            end)

          case last_user_message do
            msg when is_binary(msg) ->
              %{content: msg}

            msg when is_map(msg) ->
              content =
                msg
                |> Map.values()
                |> Enum.find(fn v -> is_binary(v) end) || ""

              %{content: content}

            _ ->
              %{content: ""}
          end
      end

    question = last_message[:content] || last_message["content"] || ""
    question = if is_binary(question), do: question, else: ""
    question_lower = String.downcase(question)

    # Simulate LLM response format
    response =
      cond do
        String.contains?(question_lower, "elixir") and String.contains?(question_lower, "what is") ->
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

        String.contains?(question_lower, "process") ->
          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     "Processes in Elixir are lightweight, isolated units of execution that communicate through message passing. Unlike threads in other languages, Elixir processes are managed by the BEAM VM, not the operating system. Each process has its own memory heap, making them extremely lightweight (a few KB). This allows Elixir applications to run thousands or even millions of concurrent processes efficiently.",
                   "role" => "assistant"
                 }
               }
             ]
           }}

        String.contains?(question_lower, "pattern matching") ->
          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     "Pattern matching is a powerful feature in Elixir that allows you to match values, data structures, and even function returns against patterns. It's used extensively for destructuring data, control flow, and function clause selection. Pattern matching makes code more declarative and concise.\n\nFor example:\n\n```elixir\n# Matching values\n{a, b, c} = {1, 2, 3} # a=1, b=2, c=3\n\n# List pattern matching\n[head | tail] = [1, 2, 3] # head=1, tail=[2, 3]\n\n# Function clause selection\ndef process({:ok, value}), do: value\ndef process({:error, reason}), do: raise(reason)\n```",
                   "role" => "assistant"
                 }
               }
             ]
           }}

        String.contains?(question_lower, "error") ->
          {:error, "Simulated error for testing purposes"}

        true ->
          {:ok,
           %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     "I don't have specific information about that. Is there something else about Elixir you'd like to know?",
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

  alias LLMAgent.{Flows, Store}

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
    {flow, state} =
      Flows.qa_agent(system_prompt, store_name: store_name, provider: MockElixirQAProvider)

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
    state =
      Enum.reduce(questions, state, fn question, current_state ->
        IO.puts("\nQuestion: #{question}")

        # Process the message through the flow
        case LLMAgent.process(flow, current_state, question) do
          {:ok, response, new_state} ->
            # Display the agent's response
            IO.puts("Assistant: #{response.data}")
            # Return updated state for next iteration
            new_state

          {:error, error, new_state} ->
            IO.puts("Error: #{error}")
            new_state
        end
      end)

    # 6. Display conversation history
    history = Store.get_llm_history(store_name)

    IO.puts("\n=== Conversation History ===")

    Enum.each(history, fn message ->
      role = Map.get(message, "role") || Map.get(message, :role)
      content = Map.get(message, "content") || Map.get(message, :content)

      case role do
        "system" ->
          IO.puts("System: #{content}")
          IO.puts("")

        "user" ->
          IO.puts("H: #{content}")

        "assistant" ->
          IO.puts("Assistant: #{content}")

        _ ->
          IO.puts("#{role}: #{content}")
      end
    end)

    IO.puts("\n=== Example Complete ===\n")
    IO.puts("To use this in your own application:\n")
    IO.puts("1. Configure your LLM provider:")
    IO.puts("   Application.put_env(:llm_agent, :provider, LLMAgent.Providers.OpenAI)")
    IO.puts("   Application.put_env(:llm_agent, :api_key, System.get_env(\"OPENAI_API_KEY\"))")
    IO.puts("")
    IO.puts("2. Initialize store and create QA agent:")
    IO.puts("   store_name = MyApp.ConversationStore")
    IO.puts("   Store.start_link(name: store_name)")
    IO.puts("   {flow, state} = LLMAgent.Flows.qa_agent(system_prompt, store_name: store_name)")
    IO.puts("")
    IO.puts("3. Process messages:")
    IO.puts("   {:ok, response} = LLMAgent.process(flow, question, state)")
    IO.puts("")
    IO.puts("4. Handle responses:")
    IO.puts("   case response do")
    IO.puts("     %{type: :response} -> handle_response(response.data)")
    IO.puts("     %{type: :error} -> handle_error(response.data)")
    IO.puts("   end")
    IO.puts("")
    IO.puts("5. Get conversation history:")
    IO.puts("   history = LLMAgent.Store.get_llm_history(store_name)")
  end
end

# Run the example
LLMAgent.Examples.SimpleQA.run()
