# Investment Portfolio Example
#
# This example demonstrates LLMAgent's dynamic workflow capabilities
# by implementing an investment portfolio advisor that responds to user requests
# and feedback through multi-step processes.

defmodule LLMAgent.Examples.InvestmentTools do
  @moduledoc """
  Mock implementations of investment analysis tools for the dynamic portfolio example.
  """

  @doc """
  Screens ETFs based on criteria and returns matching ETFs.
  """
  def screen_etfs(criteria) do
    # In a real implementation, this would query a financial data API
    etfs = [
      %{
        ticker: "VTI",
        name: "Vanguard Total Stock Market ETF",
        expense_ratio: 0.03,
        category: "US Equity",
        risk_level: "Moderate",
        avg_return: 10.2
      },
      %{
        ticker: "BND",
        name: "Vanguard Total Bond Market ETF",
        expense_ratio: 0.035,
        category: "Bond",
        risk_level: "Low",
        avg_return: 3.8
      },
      %{
        ticker: "VEA",
        name: "Vanguard FTSE Developed Markets ETF",
        expense_ratio: 0.05,
        category: "International Equity",
        risk_level: "Moderate-High",
        avg_return: 8.1
      },
      %{
        ticker: "VWO",
        name: "Vanguard FTSE Emerging Markets ETF",
        expense_ratio: 0.08,
        category: "Emerging Markets",
        risk_level: "High",
        avg_return: 9.2
      },
      %{
        ticker: "VTIP",
        name: "Vanguard Short-Term Inflation-Protected Securities ETF",
        expense_ratio: 0.04,
        category: "Inflation-Protected Bond",
        risk_level: "Low",
        avg_return: 2.5
      }
    ]

    # Filter ETFs based on criteria
    filtered_etfs =
      case criteria do
        %{"risk_level" => "Low"} ->
          Enum.filter(etfs, fn etf -> etf.risk_level == "Low" end)

        %{"risk_level" => "High"} ->
          Enum.filter(etfs, fn etf -> etf.risk_level in ["Moderate-High", "High"] end)

        %{"category" => category} ->
          Enum.filter(etfs, fn etf -> etf.category == category end)

        _ ->
          etfs
      end

    %{
      etfs: filtered_etfs,
      count: length(filtered_etfs),
      criteria: criteria
    }
  end

  @doc """
  Creates an investment portfolio from a list of ETFs with specified allocations.
  """
  def create_portfolio(etfs, risk_profile) do
    # In a real implementation, this would use sophisticated portfolio construction algorithms
    allocations =
      case risk_profile do
        "Conservative" ->
          [
            %{ticker: "BND", allocation: 0.6},
            %{ticker: "VTI", allocation: 0.2},
            %{ticker: "VEA", allocation: 0.1},
            %{ticker: "VTIP", allocation: 0.1}
          ]

        "Moderate" ->
          [
            %{ticker: "VTI", allocation: 0.5},
            %{ticker: "BND", allocation: 0.3},
            %{ticker: "VEA", allocation: 0.15},
            %{ticker: "VWO", allocation: 0.05}
          ]

        "Aggressive" ->
          [
            %{ticker: "VTI", allocation: 0.6},
            %{ticker: "VEA", allocation: 0.2},
            %{ticker: "VWO", allocation: 0.15},
            %{ticker: "BND", allocation: 0.05}
          ]

        _ ->
          # Default moderate portfolio
          [
            %{ticker: "VTI", allocation: 0.5},
            %{ticker: "BND", allocation: 0.3},
            %{ticker: "VEA", allocation: 0.15},
            %{ticker: "VWO", allocation: 0.05}
          ]
      end

    # Filter allocations to only include ETFs in the provided list
    available_tickers = Enum.map(etfs, fn etf -> etf.ticker end)

    valid_allocations =
      Enum.filter(allocations, fn alloc -> alloc.ticker in available_tickers end)

    # Normalize allocations if needed
    total_allocation = Enum.reduce(valid_allocations, 0, fn alloc, acc -> acc + alloc.allocation end)

    normalized_allocations =
      if total_allocation > 0 do
        Enum.map(valid_allocations, fn alloc ->
          Map.put(alloc, :allocation, alloc.allocation / total_allocation)
        end)
      else
        valid_allocations
      end

    # Calculate expected returns and volatility
    expected_return =
      Enum.reduce(normalized_allocations, 0, fn alloc, acc ->
        etf = Enum.find(etfs, fn e -> e.ticker == alloc.ticker end)
        acc + etf.avg_return * alloc.allocation
      end)

    # Create portfolio object
    %{
      allocations: normalized_allocations,
      risk_profile: risk_profile,
      expected_return: expected_return,
      expense_ratio: 0.05,
      risk_level: risk_profile
    }
  end

  @doc """
  Backtests a portfolio against historical data.
  """
  def backtest_portfolio(portfolio, years \\ 10) do
    # In a real implementation, this would use historical data to simulate performance
    expected_return = portfolio.expected_return
    risk_profile = portfolio.risk_profile

    # Generate mock historical performance data
    annual_returns =
      for year <- 1..years do
        base_return =
          case risk_profile do
            "Conservative" -> 4.0
            "Moderate" -> 7.0
            "Aggressive" -> 9.0
            _ -> 7.0
          end

        # Add some randomness
        volatility =
          case risk_profile do
            "Conservative" -> 0.05
            "Moderate" -> 0.1
            "Aggressive" -> 0.15
            _ -> 0.1
          end

        random_factor = :rand.normal(0, volatility)
        year_return = base_return + random_factor * 10
        %{year: 2015 + year, return: year_return}
      end

    # Calculate cumulative returns
    {cumulative_returns, _} =
      Enum.map_reduce(annual_returns, 100.0, fn year_data, acc ->
        new_value = acc * (1 + year_data.return / 100)
        {Map.put(year_data, :cumulative_value, new_value), new_value}
      end)

    # Calculate metrics
    final_value = List.last(cumulative_returns).cumulative_value
    cagr = :math.pow(final_value / 100.0, 1 / years) - 1
    max_drawdown = 0.15  # Mock value
    sharpe_ratio = (expected_return - 2.0) / (max_drawdown * 100) * 1.5  # Mock calculation

    %{
      annual_returns: cumulative_returns,
      years: years,
      initial_investment: 100.0,
      final_value: final_value,
      cagr: cagr * 100,
      max_drawdown: max_drawdown * 100,
      sharpe_ratio: sharpe_ratio,
      risk_adjusted_return: sharpe_ratio * 100
    }
  end

  @doc """
  Optimizes a portfolio based on risk preferences.
  """
  def optimize_portfolio(portfolio, preferences) do
    # In a real implementation, this would use optimization algorithms
    current_allocations = portfolio.allocations
    risk_tolerance = Map.get(preferences, "risk_tolerance", "Moderate")
    
    # Adjust allocations based on risk tolerance
    new_allocations =
      case risk_tolerance do
        "Lower" ->
          # Increase bond allocation for lower risk
          adjust_for_lower_risk(current_allocations)
          
        "Higher" ->
          # Increase equity allocation for higher risk
          adjust_for_higher_risk(current_allocations)
          
        _ ->
          # Keep the same allocations
          current_allocations
      end
      
    # Update portfolio with new allocations
    new_expected_return =
      Enum.reduce(new_allocations, 0, fn alloc, acc ->
        acc + case alloc.ticker do
          "VTI" -> 10.2 * alloc.allocation
          "BND" -> 3.8 * alloc.allocation
          "VEA" -> 8.1 * alloc.allocation
          "VWO" -> 9.2 * alloc.allocation
          "VTIP" -> 2.5 * alloc.allocation
          _ -> 7.0 * alloc.allocation
        end
      end)
      
    # Update risk profile based on new allocations
    new_risk_profile =
      case risk_tolerance do
        "Lower" -> 
          case portfolio.risk_profile do
            "Aggressive" -> "Moderate"
            "Moderate" -> "Conservative"
            _ -> "Conservative"
          end
        "Higher" ->
          case portfolio.risk_profile do
            "Conservative" -> "Moderate"
            "Moderate" -> "Aggressive"
            _ -> "Aggressive"
          end
        _ -> portfolio.risk_profile
      end
      
    # Return optimized portfolio
    %{
      allocations: new_allocations,
      risk_profile: new_risk_profile,
      expected_return: new_expected_return,
      previous_allocations: current_allocations,
      previous_risk_profile: portfolio.risk_profile,
      optimization_criteria: preferences
    }
  end
  
  # Helper functions for portfolio optimization
  
  defp adjust_for_lower_risk(allocations) do
    # Increase bond allocation, decrease equity
    Enum.map(allocations, fn alloc ->
      case alloc.ticker do
        "BND" -> %{alloc | allocation: min(0.6, alloc.allocation * 1.5)}
        "VTIP" -> %{alloc | allocation: min(0.2, alloc.allocation * 1.5)}
        "VTI" -> %{alloc | allocation: max(0.1, alloc.allocation * 0.7)}
        "VWO" -> %{alloc | allocation: max(0.0, alloc.allocation * 0.5)}
        _ -> alloc
      end
    end)
    |> normalize_allocations()
  end
  
  defp adjust_for_higher_risk(allocations) do
    # Increase equity allocation, decrease bonds
    Enum.map(allocations, fn alloc ->
      case alloc.ticker do
        "BND" -> %{alloc | allocation: max(0.1, alloc.allocation * 0.6)}
        "VTIP" -> %{alloc | allocation: max(0.0, alloc.allocation * 0.5)}
        "VTI" -> %{alloc | allocation: min(0.7, alloc.allocation * 1.3)}
        "VWO" -> %{alloc | allocation: min(0.2, alloc.allocation * 1.5)}
        _ -> alloc
      end
    end)
    |> normalize_allocations()
  end
  
  defp normalize_allocations(allocations) do
    total = Enum.reduce(allocations, 0, fn alloc, acc -> acc + alloc.allocation end)
    
    if total > 0 do
      Enum.map(allocations, fn alloc ->
        %{alloc | allocation: alloc.allocation / total}
      end)
    else
      allocations
    end
  end
end

# ---- MAIN EXAMPLE SCRIPT ----

alias LLMAgent.Examples.InvestmentTools
alias AgentForge.Store
alias LLMAgent.{Signals, Store}

# Define tool definitions for the LLMAgent workflow
defmodule LLMAgent.Examples.InvestmentTools.Tools do
  @moduledoc """
  Tool definitions for the investment portfolio example.
  In a real LLMAgent implementation, these would be registered with the agent.
  """
  
  def get_tools do
    [
      %{
        name: "etf_screener",
        description: "Screen ETFs based on criteria such as category and risk level",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "category" => %{
              "type" => "string",
              "description" => "ETF category (US Equity, Bond, International Equity, etc.)"
            },
            "risk_level" => %{
              "type" => "string",
              "description" => "Risk level (Low, Moderate, High)"
            }
          }
        },
        execute: fn args -> InvestmentTools.screen_etfs(args) end
      },
      %{
        name: "portfolio_constructor",
        description: "Create a portfolio allocation from a list of ETFs",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "etfs" => %{
              "type" => "array",
              "description" => "List of ETF tickers to include in the portfolio"
            },
            "risk_profile" => %{
              "type" => "string",
              "description" => "Risk profile (Conservative, Moderate, Aggressive)"
            }
          },
          "required" => ["risk_profile"]
        },
        execute: fn args ->
          # Convert ticker list to ETF objects
          etfs = InvestmentTools.screen_etfs(%{})[:etfs]
          
          # Filter to just the requested ETFs if specified
          selected_etfs = 
            if Map.has_key?(args, "etfs") do
              Enum.filter(etfs, fn etf -> etf.ticker in args["etfs"] end)
            else
              etfs
            end
          
          # Create portfolio
          risk_profile = Map.get(args, "risk_profile", "Moderate")
          InvestmentTools.create_portfolio(selected_etfs, risk_profile)
        end
      },
      %{
        name: "portfolio_backtester",
        description: "Run a backtest on a portfolio to see historical performance",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "portfolio" => %{
              "type" => "object",
              "description" => "Portfolio object to backtest"
            },
            "years" => %{
              "type" => "integer",
              "description" => "Number of years to backtest"
            }
          },
          "required" => ["portfolio"]
        },
        execute: fn args ->
          portfolio = args["portfolio"]
          years = Map.get(args, "years", 10)
          InvestmentTools.backtest_portfolio(portfolio, years)
        end
      },
      %{
        name: "portfolio_optimizer",
        description: "Optimize a portfolio based on preferences",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "portfolio" => %{
              "type" => "object",
              "description" => "Portfolio object to optimize"
            },
            "preferences" => %{
              "type" => "object",
              "description" => "Optimization preferences"
            }
          },
          "required" => ["portfolio", "preferences"]
        },
        execute: fn args ->
          portfolio = args["portfolio"]
          preferences = args["preferences"]
          InvestmentTools.optimize_portfolio(portfolio, preferences)
        end
      }
    ]
  end

  def get_system_prompt do
    """
    You are an investment advisor specialized in creating ETF portfolios.
    Use the available tools to create and optimize portfolios based on user requirements.
    
    When creating portfolios, follow these steps:
    1. Use etf_screener to find suitable ETFs
    2. Use portfolio_constructor to create an initial portfolio
    3. Use portfolio_backtester to evaluate performance
    4. If the user wants adjustments, use portfolio_optimizer
    
    Be thorough in your analysis and explanations, but avoid jargon.
    Always consider the user's risk tolerance and investment goals.
    """
  end
end

# This is how you would normally use LLMAgent's API in a real application:
#
# 1. Define your system prompt and tools
# system_prompt = LLMAgent.Examples.InvestmentTools.Tools.get_system_prompt()
# tools = LLMAgent.Examples.InvestmentTools.Tools.get_tools()
#
# 2. Create a conversation flow
# {flow, initial_state} = LLMAgent.Flows.conversation(system_prompt, tools)
#
# 3. Create a user message signal
# user_message = Signals.user_message("Create a retirement ETF portfolio for me.")
#
# 4. Run the flow with an LLM backend (would be handled by LLMAgent internally)
# result = LLMAgent.run(flow, user_message, initial_state)

# This example demonstrates LLMAgent's API structure without using an actual LLM
defmodule LLMAgent.Examples.InvestmentDemo do
  @moduledoc """
  Demonstrates how LLMAgent's API can be used to build multi-step investment portfolio workflows
  with dynamic decision-making based on context and user input.
  
  NOTE: This example uses mock LLM responses rather than calling a real LLM.
  In a real implementation, LLMAgent would handle the LLM integration.
  """
  
  alias LLMAgent.Examples.InvestmentTools.Tools
  
  @doc """
  Run the investment portfolio demo using LLMAgent's API structure, but with mock LLM responses.
  This demonstrates the intended usage of LLMAgent without requiring a real LLM connection.
  """
  def run do
    # Setup tools and system prompt - this is part of how you'd use LLMAgent's API
    system_prompt = Tools.get_system_prompt()
    tools = Tools.get_tools()
    
    # In a real app, you'd create a flow and initial state like this:
    # {flow, initial_state} = LLMAgent.Flows.conversation(system_prompt, tools)
    
    # For demonstration, we'll manually initialize a state object similar to what LLMAgent would use
    initial_state = %{
      system_prompt: system_prompt,
      tools: tools,
      messages: [],
      portfolio: nil,
      etfs: [],
      backtest_results: nil
    }
    
    IO.puts("\n=== Investment Portfolio Example (Using LLMAgent API Structure) ===\n")
    IO.puts("NOTE: This example uses mock responses to demonstrate the API pattern.\n")
    
    # First user message - In a real app, this would be passed to LLMAgent.run
    first_message = "Create a retirement ETF portfolio for me."
    IO.puts("User: #{first_message}\n")
    
    # In a real app: result = LLMAgent.run(flow, Signals.user_message(first_message), state)
    # But here we simulate the LLM response and tool selection
    updated_state = process_message(initial_state, first_message)
    
    # Second user message - continuing the conversation with state maintained
    second_message = "Can you reduce the risk level? I'm concerned about market volatility."
    IO.puts("\nUser: #{second_message}\n")
    
    # In a real app: result = LLMAgent.run(flow, Signals.user_message(second_message), updated_state)
    # But again, we use mock responses for demonstration
    final_state = process_message(updated_state, second_message)
    
    # Example completion
    IO.puts("\n=== Example Complete ===")
    IO.puts("This demonstration shows how LLMAgent's API can be used to build dynamic workflows")
    IO.puts("where the LLM decides which tools to call based on context and user input.")
    IO.puts("")
    IO.puts("Key LLMAgent API concepts demonstrated:")
    IO.puts("1. Creating flows with tools and system prompts")
    IO.puts("2. Maintaining conversation state across interactions")
    IO.puts("3. Using signals to process user messages")
    IO.puts("4. Handling tool calls and responses through the LLMAgent abstraction")
    
    final_state
  end
  
  # Mock implementation of an LLM-based message processor
  # This simulates how LLMAgent would process messages through the LLM and handle tool calls
  # In a real implementation, LLMAgent would handle all of this internally
  # 
  # Returns updated state with tool results and conversation history.
  @spec process_message(map(), String.t()) :: map()
  defp process_message(state, message) do
    # In a real implementation, LLMAgent would:
    # 1. Create a user_message signal
    # 2. Pass it to the LLM through a provider
    # 3. Process the response to identify tool calls
    #
    # Here we simulate those steps with mock responses
    {tool_name, tool_args, thinking} = mock_llm_response(message, state)
    
    # This would be handled by LLMAgent.Handlers.thinking_handler in a real implementation
    IO.puts("Assistant thinking: #{thinking}\n")
    
    if tool_name do
      # In a real implementation, LLMAgent would handle tool dispatch
      # Here we manually find the tool - LLMAgent.Handlers.tool_call_handler would do this
      tool = Enum.find(state.tools, fn t -> t.name == tool_name end)
      
      # Tool execution would be handled by LLMAgent.Handlers.tool_execution_handler
      IO.puts("Executing tool: #{tool_name}")
      result = tool.execute.(tool_args)
      
      # This state update would happen automatically within LLMAgent's signal flow
      updated_state = update_state(state, tool_name, result)
      
      # This would be handled by LLMAgent.Handlers.tool_result_handler
      process_tool_result(updated_state, tool_name, result, message)
    else
      # In a real implementation, LLMAgent would handle the final response generation
      # through the appropriate signal handlers
      generate_final_response(state, message)
      state
    end
  end
  
  # Update state based on tool results
  @spec update_state(map(), String.t(), any()) :: map()
  defp update_state(state, tool_name, result) do
    # Update state based on which tool was executed
    updated_state =
      case tool_name do
        "etf_screener" ->
          Map.put(state, :etfs, result.etfs)
          
        "portfolio_constructor" ->
          Map.put(state, :portfolio, result)
          
        "portfolio_backtester" ->
          Map.put(state, :backtest_results, result)
          
        "portfolio_optimizer" ->
          Map.put(state, :portfolio, result)
          
        _ -> state
      end
      
    # Add this tool execution to history
    history_entry = %{
      tool: tool_name,
      timestamp: DateTime.utc_now(),
      result: result
    }
    
    Map.update(updated_state, :history, [history_entry], fn history -> [history_entry | history] end)
  end
  
  # Simulate the LLM analyzing a tool result and deciding the next action
  @spec process_tool_result(map(), String.t(), any(), String.t()) :: map()
  defp process_tool_result(state, tool_name, result, original_message) do
    case tool_name do
      "etf_screener" ->
        # After getting ETF list, decide to construct a portfolio
        etfs = result.etfs
        thinking = "Now that I have a list of #{length(etfs)} ETFs, I should construct a balanced portfolio based on the user's needs."
        IO.puts("Assistant thinking: #{thinking}\n")
        
        # Determine risk profile from message
        risk_profile = determine_risk_profile(original_message)
        
        # Execute next tool
        {:ok, available_tools} = AgentForge.Store.get(state, :available_tools)
        next_tool = Enum.find(available_tools, fn t -> t.name == "portfolio_constructor" end)
        IO.puts("Executing tool: portfolio_constructor")
        portfolio_result = next_tool.execute.(%{"risk_profile" => risk_profile})
        
        # Update state
        updated_state = update_state(state, "portfolio_constructor", portfolio_result)
        
        # Continue to backtesting
        process_tool_result(updated_state, "portfolio_constructor", portfolio_result, original_message)
      
      "portfolio_constructor" ->
        # After portfolio construction, decide to do backtesting
        thinking = "I've constructed a portfolio. To evaluate its performance, I should run a backtest."
        IO.puts("Assistant thinking: #{thinking}\n")
        
        # Show portfolio details
        IO.puts("Created a #{result.risk_profile} risk portfolio with expected return of #{Float.round(result.expected_return, 2)}%")
        IO.puts("Allocations:")
        
        Enum.each(result.allocations, fn alloc ->
          IO.puts("  #{alloc.ticker}: #{Float.round(alloc.allocation * 100, 1)}%")
        end)
        
        # Execute backtesting
        {:ok, available_tools} = AgentForge.Store.get(state, :available_tools)
        next_tool = Enum.find(available_tools, fn t -> t.name == "portfolio_backtester" end)
        IO.puts("\nExecuting tool: portfolio_backtester")
        backtest_result = next_tool.execute.(%{"portfolio" => result})
        
        # Update state
        updated_state = update_state(state, "portfolio_backtester", backtest_result)
        
        # Generate final response for portfolio creation
        generate_portfolio_response(updated_state)
        updated_state
      
      "portfolio_optimizer" ->
        # After optimization, generate response about the changes
        thinking = "I've optimized the portfolio according to the user's risk preference. Now I'll explain the changes."
        IO.puts("Assistant thinking: #{thinking}\n")
        
        # Show portfolio details
        IO.puts("Optimized portfolio to #{result.risk_profile} risk profile with expected return of #{Float.round(result.expected_return, 2)}%")
        IO.puts("New allocations:")
        
        Enum.each(result.allocations, fn alloc ->
          IO.puts("  #{alloc.ticker}: #{Float.round(alloc.allocation * 100, 1)}%")
        end)
        
        # Generate response for the adjustment
        generate_adjustment_response(state, result)
        state
      
      _ ->
        # Default case if tool isn't recognized
        IO.puts("Assistant thinking: I'm not sure how to process this tool result. I'll provide a generic response.\n")
        generate_final_response(state, original_message)
        state
    end
  end

  # Create a mock LLM response that simulates what a real LLM would decide
  # This replaces calling a real LLM in a LLMAgent implementation
  @spec mock_llm_response(String.t(), map()) :: {String.t() | nil, map() | nil, String.t()}
  defp mock_llm_response(message, state) do
    # In a real implementation, LLMAgent would send the message to an LLM
    # and interpret the response to determine which tool to call
    # 
    # Here we use pattern matching to simulate what the LLM would decide
    cond do
      # Initial portfolio request - the LLM would choose to screen ETFs first
      String.contains?(String.downcase(message), "portfolio") and state.portfolio == nil ->
        {
          "etf_screener", 
          %{},
          "The user is asking for a retirement ETF portfolio. I should first get a list of available ETFs using the etf_screener tool."
        }
      
      # Risk reduction request - the LLM would choose to optimize the portfolio for lower risk
      String.contains?(String.downcase(message), "risk") and 
      (String.contains?(String.downcase(message), "reduce") or 
       String.contains?(String.downcase(message), "lower") or
       String.contains?(String.downcase(message), "concerned")) and
      state.portfolio != nil ->
        {
          "portfolio_optimizer",
          %{
            "portfolio" => state.portfolio,
            "preferences" => %{"risk_tolerance" => "Lower"}
          },
          "The user wants to reduce risk in their portfolio due to concerns about market volatility. I'll use the portfolio_optimizer tool to adjust for lower risk."
        }
      
      # Risk increase request - the LLM would choose to optimize for higher risk
      String.contains?(String.downcase(message), "risk") and 
      (String.contains?(String.downcase(message), "increase") or 
       String.contains?(String.downcase(message), "higher")) and
      state.portfolio != nil ->
        {
          "portfolio_optimizer",
          %{
            "portfolio" => state.portfolio,
            "preferences" => %{"risk_tolerance" => "Higher"}
          },
          "The user wants to increase risk in their portfolio. I'll use the portfolio_optimizer tool to adjust for higher risk."
        }
      
      # General follow-up - the LLM would decide no tool is needed
      state.portfolio != nil ->
        {
          nil,
          nil,
          "The user is asking about the existing portfolio. I don't need to use any tools for this, I can respond directly with the information I have."
        }
      
      # Default case - the LLM would decide to respond directly
      true ->
        {
          nil,
          nil,
          "I'm not sure what specific action to take based on this message. I'll respond directly without using tools."
        }
    end
  end

  # Generate response after portfolio creation and backtesting
  @spec generate_portfolio_response(map()) :: :ok
  defp generate_portfolio_response(state) do
    portfolio = state.portfolio
    backtest = state.backtest_results

    # Display backtest results
    IO.puts("\nBacktest Results (10 years):")
    IO.puts("  Initial investment: $#{Float.round(backtest.initial_investment, 2)}")
    IO.puts("  Final value: $#{Float.round(backtest.final_value, 2)}")
    IO.puts("  CAGR: #{Float.round(backtest.cagr, 2)}%")
    IO.puts("  Sharpe ratio: #{Float.round(backtest.sharpe_ratio, 2)}")
    IO.puts("  Max drawdown: #{Float.round(backtest.max_drawdown, 2)}%")
    
    # Generate detailed LLM-like response
    response = """
    I've created a #{String.downcase(portfolio.risk_profile)} risk retirement portfolio for you with an expected annual return of #{Float.round(portfolio.expected_return, 2)}%. 

    The portfolio consists of a diversified mix of ETFs including US stocks, international stocks, and bonds. 
    Based on historical backtesting over 10 years, an initial investment of $100 would have grown to $#{Float.round(backtest.final_value, 2)}, 
    with a compound annual growth rate of #{Float.round(backtest.cagr, 2)}%.
    
    The risk metrics show a maximum drawdown of #{Float.round(backtest.max_drawdown, 2)}% and a Sharpe ratio of #{Float.round(backtest.sharpe_ratio, 2)}, 
    which indicates a reasonable risk-adjusted return.
    
    Would you like me to adjust the risk level or make any other changes to this portfolio?
    """
    
    IO.puts("\nAssistant: #{response}")
  end

  # Generate response after portfolio adjustment
  @spec generate_adjustment_response(map(), map()) :: :ok
  defp generate_adjustment_response(state, optimized) do
    previous_portfolio = state.portfolio
    risk_change = 
      if previous_portfolio.risk_profile == "Aggressive" and optimized.risk_profile == "Moderate" or
         previous_portfolio.risk_profile == "Moderate" and optimized.risk_profile == "Conservative" do
        "Lower"
      else
        "Higher"
      end
      
    response = """
    I've adjusted your portfolio to a #{String.downcase(optimized.risk_profile)} risk profile as requested. 
    The expected annual return is now #{Float.round(optimized.expected_return, 2)}%. 

    I've #{if risk_change == "Lower", do: "increased", else: "reduced"} the allocation to bonds 
    and #{if risk_change == "Lower", do: "reduced", else: "increased"} exposure to equities, 
    particularly #{if risk_change == "Higher", do: "emerging markets", else: ""}. 
    
    This change should provide #{if risk_change == "Lower", do: "more stability with somewhat lower returns", else: "potentially higher returns with increased volatility"}. 
    Is this more aligned with your preferences?
    """
    
    IO.puts("\nAssistant: #{response}")
  end

  # Generate general response without tool use
  @spec generate_final_response(map(), String.t()) :: :ok
  defp generate_final_response(state, _message) do
    response = 
      cond do
        # If we have a portfolio but no specific tool was selected
        state.portfolio != nil ->
          """
          Based on our conversation, I understand you're interested in your investment portfolio. 
          Your current #{state.portfolio.risk_profile} risk portfolio has an expected return of #{Float.round(state.portfolio.expected_return, 2)}%.
          
          If you'd like me to make adjustments or provide more information about specific aspects of the portfolio, 
          just let me know!
          """
          
        # No portfolio created yet, generic response
        true ->
          """
          I'd be happy to help with your investment portfolio needs. To get started, 
          I can create a retirement ETF portfolio with diversified asset allocation 
          tailored to your risk preferences. Would you like me to proceed with that?
          """
      end
      
    IO.puts("\nAssistant: #{response}")
  end
  
  # Determine risk profile from user message
  @spec determine_risk_profile(String.t()) :: String.t()
  defp determine_risk_profile(message) do
    message = String.downcase(message)
    cond do
      String.contains?(message, "aggressive") or 
      String.contains?(message, "high risk") or
      String.contains?(message, "higher risk") or
      String.contains?(message, "growth") ->
        "Aggressive"
        
      String.contains?(message, "conservative") or
      String.contains?(message, "low risk") or
      String.contains?(message, "lower risk") or
      String.contains?(message, "safe") ->
        "Conservative"
        
      true ->
        "Moderate" # Default to moderate risk
    end
  end
end

# Execute the investment portfolio example demonstrating dynamic LLM workflows
#
# This example showcases how LLMAgent can simulate LLM decision-making
# to dynamically select and execute tools based on user input and context.
#
# In this example, the AgentForge/LLMAgent architecture enables:
# 1. Maintaining conversation state across multiple interactions
# 2. Dynamically deciding which tools to use based on context
# 3. Making multi-step decisions with intermediate results
# 4. Adapting to user feedback

# Run the demo with the LLMAgent mock implementation
LLMAgent.Examples.InvestmentDemo.run()

# Print additional information about extending the example
IO.puts("\n=== How To Use This With a Real LLM ===\n")
IO.puts("In a real application, instead of using mock responses, you would:")
IO.puts("1. Install the LLMAgent package and configure an LLM provider")
IO.puts("2. Use LLMAgent.Flows.conversation() to create your workflow")
IO.puts("3. Send user messages with Signals.user_message()")
IO.puts("4. Let LLMAgent handle the LLM interaction and tool execution")
IO.puts("\nExample real implementation:")
IO.puts("""  
  # Configure your LLM provider
  Application.put_env(:llm_agent, :provider, LLMAgent.Providers.OpenAI)
  Application.put_env(:llm_agent, :api_key, System.get_env("OPENAI_API_KEY"))
  
  # Create your tools and system prompt
  tools = LLMAgent.Examples.InvestmentTools.Tools.get_tools()
  system_prompt = LLMAgent.Examples.InvestmentTools.Tools.get_system_prompt()
  
  # Create a conversation flow
  {flow, state} = LLMAgent.Flows.conversation(system_prompt, tools)
  
  # Process user messages
  user_message = "Create a retirement ETF portfolio for me."
  {:ok, new_state} = LLMAgent.run(flow, Signals.user_message(user_message), state)
""")
