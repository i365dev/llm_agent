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
  require Logger

  def generate_response(messages, _opts \\ []) do
    # Debug message format
    Logger.debug("MockElixirQAProvider - Messages: #{inspect(messages)}")

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

    Logger.debug("MockElixirQAProvider - Extracted question: #{inspect(question)}")
    Logger.debug("MockElixirQAProvider - question_lower: #{inspect(question_lower)}")

    Logger.debug(
      "MockElixirQAProvider - contains 'elixir': #{String.contains?(question_lower, "elixir")}"
    )

    Logger.debug(
      "MockElixirQAProvider - contains 'what is': #{String.contains?(question_lower, "what is")}"
    )

    # Simulate LLM response format
    response =
      cond do
        String.contains?(question_lower, "elixir") and String.contains?(question_lower, "what is") ->
          Logger.debug("MockElixirQAProvider - Matched condition: 'what is elixir'")

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
          Logger.debug("MockElixirQAProvider - Matched condition: 'process'")

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
          Logger.debug("MockElixirQAProvider - Matched condition: 'pattern matching'")

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
          Logger.debug("MockElixirQAProvider - Matched condition: 'error'")
          {:error, "Simulated error for testing purposes"}

        true ->
          Logger.debug("MockElixirQAProvider - No condition matched, using default response")

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
    Enum.each(questions, fn question ->
      IO.puts("\nQuestion: #{question}")

      # Process the message through the flow
      case LLMAgent.process(flow, state, question) do
        {:ok, response, _new_state} ->
          # Display the response
          display_response(response)

        {:error, error, _state} ->
          # Display error
          IO.puts("Error: #{error}")

        {:skip, _state} ->
          # Handle skip result
          IO.puts("Processing skipped for this message type")

        unexpected ->
          # Handle any other unexpected results
          IO.puts("Unexpected result: #{inspect(unexpected)}")
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
