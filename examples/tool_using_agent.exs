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
  @behaviour LLMAgent.Provider

  @impl true
  def generate_response(messages, _opts \\ []) do
    # Get the last user message
    last_message =
      messages
      |> Enum.reverse()
      |> Enum.find(fn msg -> msg["role"] == "user" end)

    question = last_message["content"]
    question_lower = String.downcase(question)

    # Simulate LLM deciding whether to use tools
    cond do
      String.contains?(question_lower, ["calculate", "*", "+", "-", "/"]) ->
        # Simulate LLM deciding to use calculator
        expression = extract_math_expression(question)

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me calculate that for you.",
                 "tool_calls" => [
                   %{
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

      String.contains?(question_lower, ["time", "date"]) ->
        # Simulate LLM deciding to use time tool
        format = if String.contains?(question, "ISO"), do: "iso8601", else: "utc"

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I'll check the current time.",
                 "tool_calls" => [
                   %{
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

      String.contains?(question, "error") ->
        {:error, "Simulated LLM error"}

      true ->
        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I don't need any tools to answer this: #{question}",
                 "role" => "assistant"
               }
             }
           ]
         }}
    end
  end

  # Helper to extract math expression from question
  defp extract_math_expression(question) do
    cond do
      String.contains?(question, "*") ->
        Regex.run(~r/(\d+)\s*\*\s*(\d+)/, question)
        |> Enum.drop(1)
        |> Enum.join(" * ")

      String.contains?(question, "+") ->
        Regex.run(~r/(\d+)\s*\+\s*(\d+)/, question)
        |> Enum.drop(1)
        |> Enum.join(" + ")

      true ->
        "0"
    end
  end
end

defmodule LLMAgent.Examples.ToolDemo do
  @moduledoc """
  Demonstrates a tool-using agent built with LLMAgent.
  Shows proper tool registration, handling, and error management.
  """

  alias LLMAgent.{Flows, Signals, Store}

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
    # 1. Configure LLMAgent to use our mock provider
    Application.put_env(:llm_agent, :provider, MockToolUsingProvider)

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
    {flow, state} = Flows.tool_agent(system_prompt, get_tools(), store_name: store_name)

    IO.puts("\n=== Tool-Using Agent Example ===\n")
    IO.puts("This example demonstrates:")
    IO.puts("- Using LLMAgent with tools")
    IO.puts("- Tool selection and execution")
    IO.puts("- Error handling for tools\n")

    # 5. Process example questions
    questions = [
      "Calculate 42 * 73",
      "What time is it in ISO format?",
      "What's 5 + 7?",
      # Will demonstrate error handling
      "trigger an error",
      # Won't use any tools
      "Tell me a joke"
    ]

    # Process each question
    Enum.each(questions, fn question ->
      IO.puts("\nQuestion: #{question}")

      # Process through the flow
      case LLMAgent.process(flow, state, question) do
        {:ok, response, _new_state} ->
          # Display the response
          display_response(response)

        {:error, error, _state} ->
          # Display error
          IO.puts("Error: #{error}")
      end
    end)

    # Show conversation and tool interaction history
    IO.puts("\n=== Interaction History ===")
    history = Store.get_llm_history(store_name)

    Enum.each(history, fn message ->
      case message do
        %{role: "system"} ->
          IO.puts("System: #{message.content}")

        %{role: "user"} ->
          IO.puts("\nHuman: #{message.content}")

        %{role: "assistant"} ->
          IO.puts("Assistant: #{message.content}")

        %{role: "function", name: name} ->
          IO.puts("Tool (#{name}): #{message.content}")

        _ ->
          IO.puts("#{String.capitalize(message.role)}: #{message.content}")
      end
    end)

    IO.puts("\n=== Example Complete ===")

    IO.puts("""

    To use this in your own application:

    1. Define your tools:
       tools = [
         %{
           name: "my_tool",
           description: "Tool description",
           parameters: %{...},
           execute: fn args -> ... end
         }
       ]

    2. Initialize store and create tool-using agent:
       store_name = MyApp.ToolStore
       Store.start_link(name: store_name)
       {flow, state} = LLMAgent.Flows.tool_agent(system_prompt, tools, store_name: store_name)

    3. Process messages:
       {:ok, response} = LLMAgent.process(flow, Signals.user_message(question), state)

    4. Handle responses:
       case response do
         %{type: :response} -> handle_response(response.data)
         %{type: :tool_call} -> handle_tool_call(response.data)
         %{type: :error} -> handle_error(response.data)
       end

    5. Get interaction history:
       history = LLMAgent.Store.get_llm_history(store_name)
    """)
  end

  # Display different types of responses
  defp display_response(%{type: :response} = signal) do
    IO.puts("Assistant: #{signal.data}")
  end

  defp display_response(%{type: :tool_call} = signal) do
    tool = signal.data
    IO.puts("Using tool: #{tool.name} with args: #{inspect(tool.args)}")
  end

  defp display_response(%{type: :tool_result} = signal) do
    IO.puts("Tool result: #{inspect(signal.data)}")
  end

  defp display_response(%{type: :error} = signal) do
    IO.puts("Error: #{signal.data.message}")
  end

  defp display_response(other) do
    IO.puts("Unexpected response: #{inspect(other)}")
  end
end

# Run the example
LLMAgent.Examples.ToolDemo.run()
