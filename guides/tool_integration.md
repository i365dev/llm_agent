# Tool Integration

Tools extend an LLM agent's capabilities by allowing it to perform actions and access information outside of its training data. This guide explains how to create, register, and manage tools in the LLMAgent library.

## Tool Architecture

In LLMAgent, tools follow a simple structure:

1. **Name**: A unique identifier for the tool
2. **Description**: Explains what the tool does and how to use it
3. **Execute Function**: A function that implements the tool's behavior

Tools are registered with AgentForge and are available for the LLM to use during a conversation.

## Defining Tools

A tool is defined as a map with the following structure:

```elixir
tool = %{
  name: "weather_api",
  description: "Get the current weather for a location. Requires a 'location' parameter.",
  execute: fn args ->
    location = Map.get(args, "location", "")
    # API call logic here
    %{temperature: 22, conditions: "sunny", location: location}
  end
}
```

The `execute` function takes a map of arguments and returns the tool's result. The function should be designed to handle errors gracefully and return structured data.

## Registering Tools

Tools are registered when creating a conversation flow:

```elixir
tools = [
  %{name: "calculator", description: "...", execute: &MyApp.Tools.calculate/1},
  %{name: "weather", description: "...", execute: &MyApp.Tools.get_weather/1}
]

{flow, state} = LLMAgent.Flows.conversation("You are a helpful assistant.", tools)
```

## Tool Handler Mechanism

When the LLM decides to use a tool, it generates a `:tool_call` signal. The `tool_handler` function in `LLMAgent.Handlers` processes this signal:

1. Extracts the tool name and arguments
2. Looks up the tool by name
3. Executes the tool function
4. Creates a `:tool_result` signal with the result
5. Adds the tool call and result to the conversation history

Here's a simplified version of how the tool handler works:

```elixir
def tool_handler(%{type: :tool_call, data: %{name: tool_name, args: tool_args}}, state) do
  case AgentForge.Tools.get(tool_name) do
    {:ok, tool_fn} ->
      try do
        result = tool_fn.(tool_args)
        result_signal = Signals.tool_result(tool_name, result)
        new_state = Store.add_tool_call(state, tool_name, tool_args, result)
        {{:emit, result_signal}, new_state}
      rescue
        e -> 
          error_signal = Signals.error(Exception.message(e), tool_name)
          {{:emit, error_signal}, state}
      end

    {:error, reason} ->
      error_signal = Signals.error("Tool not found: #{reason}", tool_name)
      {{:emit, error_signal}, state}
  end
end
```

## Tool Result Processing

After a tool is executed, the result is processed by the `tool_result_handler`:

1. The tool result is added to the conversation history
2. A new `:thinking` signal is generated
3. The LLM is called again to process the tool result

This allows the LLM to use tool results to inform its next actions.

## Example Tools

### Calculator Tool

```elixir
calculator_tool = %{
  name: "calculator",
  description: "Perform mathematical calculations. Accepts an 'expression' parameter.",
  execute: fn args ->
    expr = Map.get(args, "expression", "")
    case Code.eval_string(expr) do
      {result, _} -> %{result: result}
      _ -> %{error: "Invalid expression"}
    end
  end
}
```

### Web Search Tool

```elixir
search_tool = %{
  name: "web_search",
  description: "Search the web for information. Requires a 'query' parameter.",
  execute: fn args ->
    query = Map.get(args, "query", "")
    case MyApp.SearchClient.search(query) do
      {:ok, results} -> %{results: results}
      {:error, reason} -> %{error: reason}
    end
  end
}
```

### Database Tool

```elixir
db_tool = %{
  name: "database_query",
  description: "Query a database. Requires a 'query' parameter.",
  execute: fn args ->
    query = Map.get(args, "query", "")
    case Repo.query(query) do
      {:ok, results} -> %{results: results}
      {:error, reason} -> %{error: reason}
    end
  end
}
```

## Best Practices

### Security Considerations

Be careful with tools that:
- Execute arbitrary code
- Make external API calls
- Access sensitive data
- Modify system state

Always validate and sanitize inputs, especially when the tool has side effects.

### Error Handling

Tools should handle errors gracefully and provide useful error messages:

```elixir
def execute(args) do
  try do
    # Tool logic
    %{result: result}
  rescue
    e in HTTPError -> %{error: "API error: #{e.message}"}
    e in Timeout -> %{error: "Request timed out"}
    _ -> %{error: "Unknown error occurred"}
  end
end
```

### Structured Results

Return structured data that's easy for the LLM to understand:

```elixir
# Good
%{
  weather: %{
    temperature: 22,
    conditions: "sunny",
    humidity: 65
  },
  location: "New York"
}

# Not as good
"Weather in New York: 22°C, sunny, 65% humidity"
```

### Tool Description

Write clear, detailed descriptions that explain:
- What the tool does
- What parameters it requires
- What format the parameters should be in
- What the tool will return

Good descriptions help the LLM use tools correctly.

## Next Steps

- Learn about [custom agents](custom_agents.html)
- Explore [LLM provider integration](provider_guide.html)
- See [advanced usage patterns](advanced_use.html)
