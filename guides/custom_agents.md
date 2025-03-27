# Creating Custom Agents

This guide explains how to create domain-specific LLM agents by extending the base functionality of LLMAgent. Custom agents can be specialized for particular tasks, domains, or interaction patterns.

## Domain-Specific Agents

While the standard conversation flow works well for general-purpose assistants, domain-specific agents can provide more specialized capabilities:

- **Financial advisors** that understand investment concepts
- **Technical support agents** with product knowledge
- **Medical assistants** that can interpret symptoms
- **Educational tutors** with teaching methodologies

## Extending Base Flows

To create a custom agent, start by extending one of the base flows:

```elixir
defmodule MyApp.FinancialAdvisor do
  alias LLMAgent.{Flows, Signals, Store}
  
  def create_agent(options \\ []) do
    # Define a domain-specific system prompt
    system_prompt = """
    You are a financial advisor specializing in retirement planning.
    Follow these guidelines when advising clients:
    - Always ask about their time horizon and risk tolerance
    - Recommend diversified investment strategies
    - Explain concepts in clear, non-technical language
    - Disclose that you're not providing personalized financial advice
    """
    
    # Define domain-specific tools
    tools = [
      %{
        name: "calculate_compound_interest",
        description: "Calculate compound interest growth. Parameters: principal, rate, time, compounds_per_year",
        execute: &MyApp.FinancialTools.calculate_compound_interest/1
      },
      %{
        name: "retirement_calculator",
        description: "Estimate retirement savings needed. Parameters: current_age, retirement_age, life_expectancy, annual_expenses",
        execute: &MyApp.FinancialTools.retirement_calculator/1
      }
    ]
    
    # Create the base conversation flow
    {flow, initial_state} = Flows.conversation(system_prompt, tools, options)
    
    # Add custom middleware if needed
    custom_flow = fn signal, state ->
      # Log all interactions for compliance
      log_interaction(signal, state)
      
      # Apply the base flow
      flow.(signal, state)
    end
    
    {custom_flow, initial_state}
  end
  
  defp log_interaction(signal, state) do
    # Implement compliance logging
    # ...
  end
end
```

## Custom Handlers

You can create custom handlers for specialized signal processing:

```elixir
defmodule MyApp.MedicalHandlers do
  alias LLMAgent.{Signals, Store}
  
  def symptom_handler(%{type: :symptom, data: symptoms}, state) do
    # Process symptoms and generate potential diagnoses
    # ...
    
    # Create a thinking signal with medical context
    thinking = Signals.thinking("Analyzing symptoms: #{symptoms}")
    {{:emit, thinking}, state}
  end
  
  def diagnosis_handler(%{type: :diagnosis, data: diagnosis}, state) do
    # Format and validate the diagnosis
    # ...
    
    # Return a response with recommendations
    response = Signals.response(formatted_diagnosis)
    {{:emit, response}, state}
  end
end
```

## Custom Signal Types

Define domain-specific signal types to represent specialized concepts:

```elixir
defmodule MyApp.MedicalSignals do
  alias AgentForge.Signal
  
  def symptom(description) do
    Signal.new(:symptom, description)
  end
  
  def diagnosis(condition, confidence, recommendations) do
    Signal.new(:diagnosis, %{
      condition: condition,
      confidence: confidence,
      recommendations: recommendations
    })
  end
  
  def prescription(medication, dosage, instructions) do
    Signal.new(:prescription, %{
      medication: medication,
      dosage: dosage,
      instructions: instructions
    })
  end
end
```

## Custom State Management

Extend the store to include domain-specific state:

```elixir
defmodule MyApp.MedicalStore do
  alias LLMAgent.Store
  
  def new(initial_state \\ %{}) do
    # Start with the base store
    base_store = Store.new(initial_state)
    
    # Add medical-specific state
    Map.merge(base_store, %{
      patient_info: %{},
      medical_history: [],
      current_symptoms: [],
      previous_diagnoses: []
    })
  end
  
  def add_patient_info(state, info) do
    put_in(state, [:patient_info], info)
  end
  
  def add_symptom(state, symptom) do
    update_in(state, [:current_symptoms], &([symptom | &1]))
  end
  
  def add_diagnosis(state, diagnosis) do
    update_in(state, [:previous_diagnoses], &([diagnosis | &1]))
  end
end
```

## Composing Custom Flows

Create domain-specific flow compositions for specialized interaction patterns:

```elixir
defmodule MyApp.MedicalFlows do
  alias LLMAgent.{Flows, Handlers}
  alias MyApp.{MedicalHandlers, MedicalStore}
  
  def diagnosis_flow(system_prompt, tools \\ [], options \\ []) do
    # Create base conversation flow
    {base_flow, initial_state} = Flows.conversation(system_prompt, tools, options)
    
    # Initialize medical-specific state
    medical_state = MedicalStore.new(initial_state)
    
    # Create a custom flow with specialized handlers
    custom_flow = fn signal, state ->
      state
      |> handle_with(&Handlers.message_handler/2, signal)
      |> handle_with(&MedicalHandlers.symptom_handler/2, signal)
      |> handle_with(&Handlers.thinking_handler/2, signal)
      |> handle_with(&Handlers.tool_handler/2, signal)
      |> handle_with(&Handlers.tool_result_handler/2, signal)
      |> handle_with(&MedicalHandlers.diagnosis_handler/2, signal)
      |> handle_with(&Handlers.response_handler/2, signal)
      |> handle_with(&Handlers.error_handler/2, signal)
    end
    
    {custom_flow, medical_state}
  end
  
  # Helper for handling signals, similar to LLMAgent.Flows implementation
  defp handle_with({:halt, _} = result, _handler, _signal), do: result
  defp handle_with({:skip, state}, handler, signal) do
    # Implementation as in LLMAgent.Flows
  end
  # Other handle_with clauses...
end
```

## Best Practices

### Domain-Specific System Prompts

Create detailed system prompts that include:

1. **Role definition**: Clearly state the specialized role and expertise
2. **Domain knowledge**: Include essential facts and concepts
3. **Guidelines**: Provide rules and constraints for the domain
4. **Examples**: Demonstrate ideal responses for common scenarios

Example for a legal assistant:

```elixir
system_prompt = """
You are a legal assistant specializing in contract law.

EXPERTISE:
- Contract formation and interpretation
- Common contractual clauses and their implications
- Basic legal principles (not legal advice)

GUIDELINES:
- Always clarify you are not providing legal advice
- Recommend consulting with a licensed attorney for specific legal questions
- Explain legal concepts in plain language
- Ask clarifying questions when details are ambiguous

EXAMPLE INTERACTIONS:
User: "What should be included in an NDA?"
Assistant: "A typical NDA (Non-Disclosure Agreement) generally includes: 1) Definition of confidential information, 2) Scope of confidentiality obligation, 3) Exclusions from confidential information, 4) Term of the agreement, and 5) Remedies for breach. However, please note that I'm not providing legal advice, and you should consult with an attorney to ensure your NDA meets your specific needs and complies with relevant laws."
"""
```

### Configuration Options

Use options to make agents configurable:

```elixir
def create_financial_advisor(options \\ []) do
  # Extract customization options
  risk_profile = Keyword.get(options, :risk_profile, :moderate)
  timezone = Keyword.get(options, :timezone, "UTC")
  include_market_data = Keyword.get(options, :include_market_data, true)
  
  # Customize system prompt based on options
  system_prompt = build_prompt(risk_profile, timezone)
  
  # Select appropriate tools based on options
  tools = select_tools(risk_profile, include_market_data)
  
  # Create the flow
  Flows.conversation(system_prompt, tools, options)
end
```

### Testing Custom Agents

Create tests for domain-specific behavior:

```elixir
defmodule MyApp.FinancialAdvisorTest do
  use ExUnit.Case
  
  test "provides retirement planning advice" do
    {flow, state} = MyApp.FinancialAdvisor.create_agent()
    signal = LLMAgent.Signals.user_message("I'm 30 years old and want to retire at 65. How much should I save?")
    
    {:ok, result, _new_state} = AgentForge.process(flow, state, signal)
    
    assert result.type == :response
    assert String.contains?(result.data, "retirement")
    assert String.contains?(result.data, "save")
  end
  
  test "uses retirement calculator tool" do
    {flow, state} = MyApp.FinancialAdvisor.create_agent()
    signal = LLMAgent.Signals.user_message("Calculate how much I need to retire if I'm currently 30, want to retire at 65, and need $50,000 per year.")
    
    {:ok, tool_call, new_state} = AgentForge.process(flow, state, signal)
    
    assert tool_call.type == :tool_call
    assert tool_call.data.name == "retirement_calculator"
  end
end
```

## Real-World Examples

### Educational Tutor

```elixir
defmodule MyApp.MathTutor do
  alias LLMAgent.{Flows, Signals}
  
  def create_tutor(subject \\ :algebra, difficulty \\ :intermediate) do
    # Build appropriate system prompt for subject and difficulty
    system_prompt = """
    You are a math tutor specializing in #{subject} at the #{difficulty} level.
    Guide students through problems step-by-step, don't just give answers.
    Ask questions to check understanding and provide hints when students are stuck.
    """
    
    # Create appropriate tools
    tools = [
      %{
        name: "equation_solver",
        description: "Solve mathematical equations. Parameter: equation",
        execute: &MyApp.MathTools.solve_equation/1
      },
      %{
        name: "plot_function",
        description: "Create a text representation of a function graph. Parameter: function",
        execute: &MyApp.MathTools.plot_function/1
      }
    ]
    
    # Create the flow
    Flows.conversation(system_prompt, tools)
  end
end
```

### Customer Support Agent

```elixir
defmodule MyApp.SupportAgent do
  alias LLMAgent.{Flows, Signals}
  
  def create_agent(product, knowledge_base) do
    # Build system prompt with product details
    system_prompt = """
    You are a customer support agent for #{product}.
    Use the knowledge base to answer questions accurately.
    For technical issues, ask for relevant details like error messages.
    For billing or account issues, direct customers to appropriate resources.
    """
    
    # Create support-specific tools
    tools = [
      %{
        name: "search_knowledge_base",
        description: "Search the knowledge base for articles. Parameter: query",
        execute: fn args -> MyApp.Support.search_kb(knowledge_base, args["query"]) end
      },
      %{
        name: "create_ticket",
        description: "Create a support ticket. Parameters: issue, severity, description",
        execute: &MyApp.Support.create_ticket/1
      }
    ]
    
    # Create the flow
    Flows.conversation(system_prompt, tools)
  end
end
```

## Next Steps

- Explore [advanced usage patterns](advanced_use.html)
- Learn about [LLM provider integration](provider_guide.html)
- See the [architecture overview](architecture.html) for more extension points
