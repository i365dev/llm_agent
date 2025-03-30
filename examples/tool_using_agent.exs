# Tool-Using Agent Example
#
# This example demonstrates how to create an LLM-powered agent
# that can use tools to perform calculations and get the current time.
# It shows how to properly implement tool-using capabilities with LLMAgent.
#
# Key concepts demonstrated:
# 1. Configuring a mock LLM provider that can handle tool calls
# 2. Defining and registering tools
# 3. Processing tool calls and results
# 4. Error handling for tool execution
#
# Run with: mix run examples/tool_using_agent.exs

# First, let's define a mock LLM provider that can handle tool usage
defmodule MockToolUsingProvider do
  require Logger
  # Define a custom LLM provider without behavior

  def generate_response(messages, opts \\ []) do
    # For debugging
    Logger.debug("MockToolUsingProvider messages: #{inspect(messages)}")
    Logger.debug("MockToolUsingProvider opts: #{inspect(opts)}")

    # Get the last user message with more robust approach
    last_message = find_last_user_message(messages)

    # Extract question from various possible formats
    question = extract_content(last_message)
    Logger.debug("Extracted question: #{inspect(question)}")

    question_lower = String.downcase(question)

    # Get tools from opts, handling both keyword list and map formats
    # We don't actually use the tools, just acknowledging the parameter
    _tools =
      cond do
        is_list(opts) -> Keyword.get(opts, :tools, [])
        is_map(opts) -> Map.get(opts, :tools, [])
        true -> []
      end

    # Check for math expression patterns with better pattern matching
    has_math_expr =
      Regex.match?(~r/\d+\s*[\*\+\-\/]\s*\d+/, question) or
        String.contains?(question_lower, ["calculate", "compute"]) or
        (String.contains?(question_lower, ["what is", "what's"]) and
           Regex.match?(~r/\d+/, question))

    # Check for time-related keywords    
    is_time_query = String.contains?(question_lower, ["time", "date", "clock", "hour"])

    # Detect error request
    is_error_request = String.contains?(question_lower, ["error", "fail", "exception"])

    Logger.debug(
      "Question analysis - Math: #{has_math_expr}, Time: #{is_time_query}, Error: #{is_error_request}"
    )

    # Determine response based on content
    cond do
      has_math_expr ->
        # Simulate LLM deciding to use calculator
        expression = extract_math_expression(question)
        Logger.debug("Using calculator with expression: #{expression}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me calculate that for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "calculator",
                       "arguments" => Jason.encode!(%{"expression" => expression})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_time_query ->
        # Simulate LLM deciding to use time tool
        format = if String.contains?(question, "ISO"), do: "iso8601", else: "utc"
        Logger.debug("Using time tool with format: #{format}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I'll check the current time for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "current_time",
                       "arguments" => Jason.encode!(%{"format" => format})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_error_request ->
        Logger.debug("Generating simulated error")
        {:error, "Simulated LLM error for testing purposes"}

      true ->
        Logger.debug("Providing direct response")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I don't need any tools to answer: \"#{question}\". This is a direct response.",
                 "role" => "assistant"
               }
             }
           ]
         }}
    end
  end

  # Find the last user message with a more robust approach
  defp find_last_user_message(messages) do
    user_message =
      messages
      |> Enum.reverse()
      |> Enum.find(fn msg ->
        cond do
          is_map(msg) ->
            role = Map.get(msg, "role") || Map.get(msg, :role, "")
            String.downcase(role) == "user"

          is_list(msg) ->
            false

          true ->
            false
        end
      end)

    Logger.debug("Found user message: #{inspect(user_message)}")
    user_message
  end

  # Extract content from various message formats
  defp extract_content(message) do
    cond do
      is_nil(message) ->
        "unknown query"

      is_map(message) ->
        content = Map.get(message, "content") || Map.get(message, :content, "")
        if content == "", do: "unknown query", else: content

      is_binary(message) ->
        message

      true ->
        "unknown query"
    end
  end

  # Helper to extract math expression from question
  defp extract_math_expression(question) do
    # First try to extract direct expression like "25 * 4"
    direct_match = Regex.run(~r/(\d+)\s*([\*\+\-\/])\s*(\d+)/, question)

    case direct_match do
      [_full_match, num1, operator, num2] ->
        "#{num1} #{operator} #{num2}"

      _ ->
        # Otherwise try specific patterns
        cond do
          String.contains?(question, "*") ->
            Regex.run(~r/(\d+)\s*\*\s*(\d+)/, question)
            |> case do
              # Default if no match
              nil -> "25 * 4"
              [_, num1, num2] -> "#{num1} * #{num2}"
            end

          String.contains?(question, "+") ->
            Regex.run(~r/(\d+)\s*\+\s*(\d+)/, question)
            |> case do
              # Default if no match
              nil -> "2 + 2"
              [_, num1, num2] -> "#{num1} + #{num2}"
            end

          true ->
            # Default expression
            "25 * 4"
        end
    end
  end
end

defmodule LLMAgent.Examples.ToolDemo do
  @moduledoc """
  Demonstrates a tool-using agent built with LLMAgent.
  Shows proper tool registration, handling, and error management.
  """

  alias LLMAgent.{Flows, Store}

  @doc """
  Define tools that the agent can use
  """
  def get_tools do
    [
      %{
        name: "calculator",
        description: "Perform mathematical calculations",
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
          expr = args["expression"]

          try do
            {result, _} = Code.eval_string(expr)
            %{result: result}
          rescue
            e -> %{error: "Failed to evaluate: #{inspect(e)}"}
          end
        end
      },
      %{
        name: "current_time",
        description: "Get the current time",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "format" => %{
              "type" => "string",
              "enum" => ["iso8601", "utc", "unix"]
            }
          }
        },
        execute: fn args ->
          now = DateTime.utc_now()

          case args["format"] do
            "iso8601" -> %{time: DateTime.to_iso8601(now)}
            "unix" -> %{time: DateTime.to_unix(now)}
            _ -> %{time: DateTime.to_string(now)}
          end
        end
      }
    ]
  end

  def run do
    # 2. Create store for this example
    store_name = :tool_using_store
    _store = Store.start_link(name: store_name)

    # 3. Create system prompt for tool-using agent
    system_prompt = """
    You are a helpful assistant that can use tools to help answer questions.
    Available tools:
    - calculator: For mathematical calculations
    - current_time: To get the current time in different formats

    Use tools whenever relevant to provide accurate answers.
    """

    # 4. Create a conversation flow with tools and store
    tools = get_tools()

    {flow, state} =
      Flows.tool_agent(system_prompt, tools,
        store_name: store_name,
        provider: MockToolUsingProvider
      )

    IO.puts("\n=== Tool-Using Agent Example ===\n")
    IO.puts("This example demonstrates:")
    IO.puts("- Using LLMAgent with tools")
    IO.puts("- Tool selection and execution")
    IO.puts("- Error handling for tool calls\n")

    # 5. Process example questions that use different tools
    questions = [
      "What is 25 * 4?",
      "What's the current time?",
      "What's the current time in ISO format?",
      "Tell me something about Elixir",
      "Generate an error to test error handling"
    ]

    # Process each question
    _final_state =
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
    IO.puts("1. Define tools:")
    IO.puts("   tools = [")

    IO.puts(
      "     %{name: \"my_tool\", description: \"...\", parameters: %{...}, execute: fn args -> ... end}"
    )

    IO.puts("   ]")
    IO.puts("")
    IO.puts("2. Create tool agent:")
    IO.puts("   store_name = MyApp.ConversationStore")
    IO.puts("   Store.start_link(name: store_name)")

    IO.puts(
      "   {flow, state} = LLMAgent.Flows.tool_agent(system_prompt, tools, store_name: store_name, provider: MyProvider)"
    )

    IO.puts("")
    IO.puts("3. Process messages:")
    IO.puts("   {:ok, response} = LLMAgent.process(flow, question, state)")
    IO.puts("")
    IO.puts("4. Tool calls will be automatically executed by the flow")
  end
end

# Run the example
LLMAgent.Examples.ToolDemo.run()
