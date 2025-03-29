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

# Define tool definitions for the AgentForge workflow
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

# Note: In a real application, we would use the actual LLMAgent.Flows API
# We'd create a flow with the tools and system prompt, then run the flow
# For example:
# {flow, initial_state} = LLMAgent.Flows.conversation(system_prompt, tools)
# AgentForge.run(flow, initial_state, user_message: "Create a retirement ETF portfolio for me.")

# This example demonstrates LLMAgent's dynamic workflow capabilities
defmodule LLMAgent.Examples.InvestmentDemo do
  @moduledoc """
  Demonstrates how LLMAgent can handle multi-step investment portfolio workflows
  with dynamic decision-making based on context and user input.
  """
  
  alias LLMAgent.Examples.InvestmentTools.Tools
  
  @doc """
  Run the investment portfolio demo with dynamic tool selection and state management
  that simulates the way AgentForge and LLMAgent would handle this conversation.
  """
  def run do
    # Initialize conversation state (similar to AgentForge.Store)
    initial_state = %{
      history: [],
      available_tools: Tools.get_tools(),
      portfolio: nil,
      etfs: [],
      backtest_results: nil
    }
    
    IO.puts("\n=== Investment Portfolio Example ===\n")
    
    # First user message simulation
    first_message = "Create a retirement ETF portfolio for me."
    IO.puts("User: #{first_message}\n")
    
    # Process first message - this simulates AgentForge.run with dynamic tool selection
    updated_state = process_message(initial_state, first_message)
    
    # Second user message - feedback on the portfolio
    second_message = "Can you reduce the risk level? I'm concerned about market volatility."
    IO.puts("\nUser: #{second_message}\n")
    
    # Process second message - notice how we pass the updated state
    final_state = process_message(updated_state, second_message)
    
    # Example completion
    IO.puts("\n=== Example Complete ===")
    IO.puts("This demonstration shows how LLMAgent enables truly dynamic workflows")
    IO.puts("where the LLM decides the next steps based on context and user input.")
    IO.puts("")
    IO.puts("Key concepts demonstrated:")
    IO.puts("1. State persistence across interactions")
    IO.puts("2. Dynamic tool selection based on context")
    IO.puts("3. Multi-step reasoning with intermediate results")
    IO.puts("4. Adaptive responses to user feedback")
    
    final_state
  end
  
  # Simulate the LLM's message processing and dynamic tool selection
  # Process a user message by simulating LLM decision-making.
  # Similar to how AgentForge would handle messages in a real implementation,
  # this function analyzes the message, selects appropriate tools, and updates state.
  #
  # Returns updated state with tool results and conversation history.
  @spec process_message(map(), String.t()) :: map()
  defp process_message(state, message) do
    # In a real implementation, this would call the LLM to analyze the message
    # and decide which tool to use. Here we simulate that decision process.
    {tool_name, tool_args, thinking} = simulate_llm_tool_selection(message, state)
    
    # Show the "thinking" process that would happen in the LLM
    IO.puts("Assistant thinking: #{thinking}\n")
    
    if tool_name do
      # Find the selected tool
      tool = Enum.find(state.available_tools, fn t -> t.name == tool_name end)
      
      # Execute the tool with arguments
      IO.puts("Executing tool: #{tool_name}")
      result = tool.execute.(tool_args)
      
      # Update state with result
      updated_state = update_state(state, tool_name, result)
      
      # Process the tool result (simulating LLM analyzing result and deciding next action)
      process_tool_result(updated_state, tool_name, result, message)
    else
      # If no tool was selected, generate a final response
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
        next_tool = Enum.find(state.available_tools, fn t -> t.name == "portfolio_constructor" end)
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
        next_tool = Enum.find(state.available_tools, fn t -> t.name == "portfolio_backtester" end)
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

  # Simulate LLM's decision-making process for selecting a tool
  @spec simulate_llm_tool_selection(String.t(), map()) :: {String.t() | nil, map() | nil, String.t()}
  defp simulate_llm_tool_selection(message, state) do
    cond do
      # Initial portfolio request - decide to screen ETFs first
      String.contains?(String.downcase(message), "portfolio") and state.portfolio == nil ->
        {
          "etf_screener", 
          %{},
          "The user is asking for a retirement ETF portfolio. I should first get a list of available ETFs using the etf_screener tool."
        }
      
      # Risk reduction request - use portfolio optimizer with lower risk preference  
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
      
      # Risk increase request - use portfolio optimizer with higher risk preference
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
      
      # General follow-up question about portfolio - no tool needed
      state.portfolio != nil ->
        {
          nil,
          nil,
          "The user is asking about the existing portfolio. I don't need to use any tools for this, I can respond directly with the information I have."
        }
      
      # Default case - unclear request
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

# Run the demo with the new dynamic simulation approach
LLMAgent.Examples.InvestmentDemo.run()

# Print additional information about extending the example
IO.puts("\n=== Further Extensions ===\n")
IO.puts("Try modifying this example to:")
IO.puts("1. Add additional tools (tax analysis, retirement planning)")
IO.puts("2. Implement more complex LLM simulation logic")
IO.puts("3. Integrate with real LLM providers via LLMAgent plugins")
IO.puts("4. Create a more sophisticated portfolio construction algorithm")
IO.puts("\nThis example demonstrates the core pattern behind LLMAgent's dynamic workflow capabilities.")
IO.puts("In a real implementation, the LLM would make the decisions that are simulated here.")
