##
# Tool-Using Agent Example
#
# This example demonstrates how to create an LLM-powered agent
# that can use tools to perform calculations, get weather information,
# convert temperatures, store and retrieve information, and more.
# It shows how to properly implement tool-using capabilities with LLMAgent.
#
# Key concepts demonstrated:
# 1. Configuring a mock LLM provider that can handle tool calls
# 2. Defining and registering tools
# 3. Processing tool calls and results
# 4. Handling chained tool calls (multi-step workflows)
# 5. Stateful information storage and retrieval
# 6. Error handling for tool execution
#
# Run with: mix run examples/tool_using_agent.exs
#

##
# Mock data provider that demonstrates tool-using capabilities
##
defmodule MockToolUsingProvider do
  require Logger

  @doc """
  Generate a response for the given messages, simulating a tool-using LLM.
  This mock provider analyzes the input and determines whether to use a tool
  or return a default response.
  """
  def generate_response(messages, _opts \\ []) do
    Logger.debug("Generating response for messages: #{inspect(messages)}")

    # Extract the most recent user message (the question)
    last_message = List.last(messages)
    question = last_message["content"] || last_message[:content]
    question_lower = String.downcase(question)

    # Set up detection for various queries
    # Math calculation
    has_math_expr =
      String.contains?(question_lower, ["calculate", "what is", "what's", "solve"]) and
        Regex.match?(~r/\d[\s*+\-\/\d\.\(\)]+\d/, question)

    # Time queries
    is_time_query =
      String.contains?(question_lower, ["time", "what's the time", "what time", "clock", "date"]) and
        not has_math_expr

    # Query for stored information retrieval
    is_get_info_query =
      String.contains?(question_lower, ["what", "get", "retrieve", "recall"]) and
        String.contains?(question_lower, ["my", "the", "our", "stored", "saved", "name"])

    # Chain queries - Temperature query with unit conversion
    is_chain_weather_temp_query =
      String.contains?(question_lower, ["temperature", "how hot", "how cold"]) and
        (String.contains?(question_lower, ["in fahrenheit", "in celsius"]) or
           String.contains?(question_lower, ["convert", "fahrenheit", "celsius"])) and
        Regex.match?(~r/\b[A-Z][a-z]+(\s+[A-Z][a-z]+)*\b/, question)

    # Weather queries - Improved matching logic to avoid false positives
    # Exclude cases that are clearly info retrieval or chained temp queries
    is_weather_query =
      (String.contains?(question_lower, ["weather", "temperature", "how hot", "how cold"]) or
         (String.contains?(question_lower, ["what's", "what is", "how's"]) and
            String.contains?(question_lower, ["in", "at"]) and
            Regex.match?(~r/\b[A-Z][a-z]+(\s+[A-Z][a-z]+)*\b/, question))) and
        not is_get_info_query and
        not is_chain_weather_temp_query

    # Temperature conversion
    is_convert_temp_query =
      String.contains?(question_lower, ["convert", "temperature", "celsius", "fahrenheit"]) and
        not is_chain_weather_temp_query

    # Store information
    is_store_info_query =
      String.contains?(question_lower, ["store", "save", "remember", "record", "my name"])

    # Check if this is an explicit error request for testing error handling
    is_error_request =
      String.contains?(question_lower, ["error", "generate an error", "test error"])

    Logger.debug(
      "Question analysis - Math: #{has_math_expr}, Time: #{is_time_query}, Weather: #{is_weather_query}, " <>
        "Convert: #{is_convert_temp_query}, Store: #{is_store_info_query}, Get: #{is_get_info_query}, Error: #{is_error_request}, Chain Weather Temp: #{is_chain_weather_temp_query}"
    )

    # Determine response based on content
    cond do
      is_error_request ->
        # Generate an error response for testing error handling
        {:error, "This is a test error response"}

      has_math_expr ->
        # Extract math expression
        math_expr = extract_math_expression(question)
        Logger.debug("Using calculator tool for expression: #{math_expr}")

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
                       "arguments" => Jason.encode!(%{"expression" => math_expr})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_time_query ->
        # Determine format based on the query
        format =
          cond do
            String.contains?(question_lower, ["iso", "iso8601"]) -> "iso8601"
            String.contains?(question_lower, ["utc"]) -> "utc"
            String.contains?(question_lower, ["unix"]) -> "unix"
            true -> "iso8601"
          end

        Logger.debug("Using time tool with format: #{format}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me check the current time for you.",
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

      is_weather_query ->
        # Extract city name using regex
        city = extract_city(question) || "New York"
        Logger.debug("Using weather tool for city: #{city}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me retrieve that information for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "fetch_weather",
                       "arguments" => Jason.encode!(%{"city" => city})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_chain_weather_temp_query ->
        # Extract city name using regex
        city = extract_city(question) || "New York"
        Logger.debug("Using weather tool for city: #{city}")

        # Determine the target unit based on the query
        to_unit =
          if String.contains?(question_lower, "fahrenheit") do
            "fahrenheit"
          else
            "celsius"
          end

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me check the weather for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "fetch_weather",
                       "arguments" => Jason.encode!(%{"city" => city}),
                       "next" => [
                         %{
                           "name" => "convert_temperature",
                           "arguments" =>
                             Jason.encode!(%{
                               "value" => "temperature_celsius",
                               "from_unit" => "celsius",
                               "to_unit" => to_unit
                             })
                         }
                       ]
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_convert_temp_query ->
        # Extract temperature value and units
        {value, from_unit, to_unit} = extract_temp_conversion(question)
        Logger.debug("Using convert tool: #{value} #{from_unit} to #{to_unit}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I'll convert that temperature for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "convert_temperature",
                       "arguments" =>
                         Jason.encode!(%{
                           "value" => value,
                           "from_unit" => from_unit,
                           "to_unit" => to_unit
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_store_info_query ->
        # Extract key and value
        {key, value} = extract_key_value(question)
        Logger.debug("Using store tool: #{key} = #{value}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I'll store that information for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "store_information",
                       "arguments" => Jason.encode!(%{"key" => key, "value" => value})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      is_get_info_query ->
        # Extract key
        key = extract_key(question)
        Logger.debug("Using get tool for key: #{key}")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me retrieve that information for you.",
                 "tool_calls" => [
                   %{
                     "id" => "call_#{:rand.uniform(999_999)}",
                     "type" => "function",
                     "function" => %{
                       "name" => "get_information",
                       "arguments" => Jason.encode!(%{"key" => key})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      true ->
        # Fallback for generic responses when no tool needed
        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I'm not sure how to help with that specific request."
               }
             }
           ]
         }}
    end
  end

  # Extract a mathematical expression from a question
  defp extract_math_expression(question) do
    # Use regex to find the first mathematical expression
    case Regex.run(~r/\d[\s*+\-\/\d\.\(\)]+\d/, question) do
      [expression | _] -> String.trim(expression)
      # Default expression if nothing found
      _ -> "1 + 1"
    end
  end

  # Extract city from a question
  defp extract_city(question) do
    # Try to find a capitalized word that could be a city name
    case Regex.run(~r/\b([A-Z][a-z]+(\s+[A-Z][a-z]+)*)\b/, question) do
      [city | _] -> city
      _ -> nil
    end
  end

  # Extract temperature conversion parameters
  defp extract_temp_conversion(question) do
    # Default values
    value = 25
    from_unit = "celsius"

    # Try to extract a numeric value
    value =
      case Regex.run(~r/\b(\d+(\.\d+)?)\b/, question) do
        [value_str | _] -> String.to_float("#{value_str}.0")
        _ -> value
      end

    # Determine units
    from_unit =
      cond do
        Regex.match?(~r/\b\d+(\.\d+)?\s*(c|celsius|centigrade)\b/i, question) -> "celsius"
        Regex.match?(~r/\b\d+(\.\d+)?\s*(f|fahrenheit)\b/i, question) -> "fahrenheit"
        true -> from_unit
      end

    # Determine target unit
    to_unit =
      cond do
        String.contains?(String.downcase(question), ["to celsius", "to c", "in celsius", "in c"]) ->
          "celsius"

        String.contains?(String.downcase(question), [
          "to fahrenheit",
          "to f",
          "in fahrenheit",
          "in f"
        ]) ->
          "fahrenheit"

        from_unit == "celsius" ->
          "fahrenheit"

        true ->
          "celsius"
      end

    {value, from_unit, to_unit}
  end

  # Extract key and value for storing information
  defp extract_key_value(question) do
    question_lower = String.downcase(question)

    # Default values
    key = "name"
    value = "unknown"

    # Try to identify the type of information being stored
    key =
      cond do
        String.contains?(question_lower, ["name"]) -> "name"
        String.contains?(question_lower, ["age"]) -> "age"
        String.contains?(question_lower, ["address"]) -> "address"
        String.contains?(question_lower, ["phone"]) -> "phone"
        String.contains?(question_lower, ["email"]) -> "email"
        true -> key
      end

    # Try to extract the value
    value =
      case Regex.run(~r/(?:as|is|to)\s+([A-Za-z0-9]+(?:\s+[A-Za-z0-9]+)*)/, question) do
        [_, value] ->
          value

        _ ->
          case Regex.run(
                 ~r/(?:store|save|remember|record)\s+my\s+[a-z]+\s+([A-Za-z0-9]+(?:\s+[A-Za-z0-9]+)*)/,
                 question_lower
               ) do
            [_, value] -> value
            _ -> value
          end
      end

    {key, value}
  end

  # Extract key for retrieving information
  defp extract_key(question) do
    question_lower = String.downcase(question)

    # Try to identify the type of information being retrieved
    cond do
      String.contains?(question_lower, ["name"]) -> "name"
      String.contains?(question_lower, ["age"]) -> "age"
      String.contains?(question_lower, ["address"]) -> "address"
      String.contains?(question_lower, ["phone"]) -> "phone"
      String.contains?(question_lower, ["email"]) -> "email"
      # Default to name if unclear
      true -> "name"
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
      },
      %{
        name: "fetch_weather",
        description: "Get the current weather temperature for a city",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "city" => %{
              "type" => "string",
              "description" => "The name of the city"
            }
          },
          "required" => ["city"]
        },
        execute: fn args ->
          city = args["city"]
          # Simulate API call with random temperatures
          temp_c = 10 + :rand.uniform(25)

          %{
            city: city,
            temperature_celsius: temp_c,
            unit: "celsius",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        end
      },
      %{
        name: "convert_temperature",
        description: "Convert temperature between Celsius and Fahrenheit",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "value" => %{
              "type" => "number",
              "description" => "The temperature value to convert"
            },
            "from_unit" => %{
              "type" => "string",
              "enum" => ["celsius", "fahrenheit"],
              "description" => "The source unit"
            },
            "to_unit" => %{
              "type" => "string",
              "enum" => ["celsius", "fahrenheit"],
              "description" => "The target unit"
            }
          },
          "required" => ["value", "from_unit", "to_unit"]
        },
        execute: fn args ->
          value = args["value"]
          from_unit = args["from_unit"]
          to_unit = args["to_unit"]

          result =
            cond do
              from_unit == to_unit ->
                value

              from_unit == "celsius" && to_unit == "fahrenheit" ->
                value * 9 / 5 + 32

              from_unit == "fahrenheit" && to_unit == "celsius" ->
                (value - 32) * 5 / 9

              true ->
                nil
            end

          %{
            original_value: value,
            original_unit: from_unit,
            converted_value: result,
            converted_unit: to_unit
          }
        end
      },
      %{
        name: "store_information",
        description: "Store a piece of information for later retrieval",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "key" => %{
              "type" => "string",
              "description" => "The identifier for the information"
            },
            "value" => %{
              "type" => "string",
              "description" => "The information to store"
            }
          },
          "required" => ["key", "value"]
        },
        execute: fn args ->
          key = args["key"]
          value = args["value"]

          # Store in process dictionary for simplicity
          # In a real app, use proper state management
          Process.put({:info_store, key}, value)

          %{
            status: "stored",
            key: key
          }
        end
      },
      %{
        name: "get_information",
        description: "Retrieve a previously stored piece of information",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "key" => %{
              "type" => "string",
              "description" => "The identifier for the information to retrieve"
            }
          },
          "required" => ["key"]
        },
        execute: fn args ->
          key = args["key"]
          value = Process.get({:info_store, key})

          if value do
            %{
              status: "found",
              key: key,
              value: value
            }
          else
            %{
              status: "not_found",
              key: key
            }
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
    - fetch_weather: Get the current weather temperature for a city
    - convert_temperature: Convert temperature between Celsius and Fahrenheit
    - store_information: Store a piece of information for later retrieval
    - get_information: Retrieve a previously stored piece of information

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
    IO.puts("- Error handling for tool calls")
    IO.puts("- Chain tool calling (multi-step workflows)")
    IO.puts("- Stateful information storage and retrieval\n")

    # 5. Process example questions that use different tools
    questions = [
      "What is 25 * 4?",
      "What's the current time?",
      "What's the current time in ISO format?",
      "Tell me something about Elixir",
      "Generate an error to test error handling",
      "What's the weather like in New York?",
      "Convert 25 Celsius to Fahrenheit",
      "Store my name as John",
      "What's my name?",
      "What's the temperature in New York in Fahrenheit?"
    ]

    # Process each question with enhanced result tracking
    _final_state =
      Enum.reduce(questions, state, fn question, current_state ->
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Question: #{question}")
        IO.puts(String.duplicate("-", 80))

        # Process the message through the flow
        case LLMAgent.process(flow, current_state, question) do
          {:ok, response, new_state} ->
            # Display the agent's initial response
            IO.puts("Assistant's initial response: #{response.data}")

            # Check for tool calls
            tool_calls = get_tool_calls(store_name)

            if length(tool_calls) > 0 do
              IO.puts("\nTool calls detected:")
              display_tool_calls(tool_calls)

              # Get tool results
              tool_results = get_tool_results(store_name)

              if length(tool_results) > 0 do
                IO.puts("\nTool results:")
                display_tool_results(tool_results)
              end
            end

            # Return updated state for next iteration
            new_state

          {:error, error, new_state} ->
            IO.puts("Error: #{error}")
            new_state
        end
      end)

    # 6. Display conversation history with enhanced detail
    display_enhanced_conversation_history(store_name)

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

  # Helper functions for enhanced display

  # Get tool calls from store
  defp get_tool_calls(store_name) do
    # This is a simplified version - in a real scenario we would properly
    # extract this information from the Store
    Process.get({:tool_calls, store_name}) || []
  end

  # Get tool results from store
  defp get_tool_results(store_name) do
    # This is a simplified version - in a real scenario we would properly
    # extract this information from the Store
    Process.get({:tool_results, store_name}) || []
  end

  # Display tool calls
  defp display_tool_calls(tool_calls) do
    Enum.each(tool_calls, fn call ->
      IO.puts("  - Tool: #{call.name}")
      IO.puts("    Arguments: #{inspect(call.arguments)}")

      if Map.has_key?(call, :next) && !is_nil(call.next) do
        IO.puts("    Next tools in chain:")

        Enum.each(call.next, fn next_tool ->
          IO.puts("      - #{next_tool.name} with args: #{inspect(next_tool.arguments)}")
        end)
      end
    end)
  end

  # Display tool results
  defp display_tool_results(tool_results) do
    Enum.each(tool_results, fn result ->
      IO.puts("  - Tool: #{result.name}")
      IO.puts("    Result: #{inspect(result.result)}")
    end)
  end

  # Display enhanced conversation history
  defp display_enhanced_conversation_history(store_name) do
    history = Store.get_llm_history(store_name)

    IO.puts("\n=== Conversation History ===")

    Enum.each(history, fn message ->
      role = Map.get(message, "role") || Map.get(message, :role)
      content = Map.get(message, "content") || Map.get(message, :content)

      # Tool calls in content
      tool_calls = Map.get(message, "tool_calls") || Map.get(message, :tool_calls)

      case role do
        "system" ->
          IO.puts("System: #{content}")
          IO.puts("")

        "user" ->
          IO.puts("Human: #{content}")

        "assistant" ->
          IO.puts("Assistant: #{content}")

          # Display tool calls if present
          if tool_calls && length(tool_calls) > 0 do
            IO.puts("  Tool calls:")

            Enum.each(tool_calls, fn tool_call ->
              function = Map.get(tool_call, "function") || Map.get(tool_call, :function)
              name = Map.get(function, "name") || Map.get(function, :name)
              args = Map.get(function, "arguments") || Map.get(function, :arguments)
              IO.puts("    - #{name}(#{args})")
            end)
          end

        _ ->
          IO.puts("#{role}: #{content}")
      end
    end)
  end
end

# Run the example
LLMAgent.Examples.ToolDemo.run()
