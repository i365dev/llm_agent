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

# Define tool definitions
# In a real LLMAgent implementation, these would be registered with the agent
# and used through the LLMAgent API
_tools = [
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
      "required" => ["etfs", "risk_profile"]
    },
    execute: fn args ->
      # Convert ticker list to ETF objects
      etfs = InvestmentTools.screen_etfs(%{})[:etfs]
      
      # Filter to just the requested ETFs
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

# Create a system prompt for the investment advisor
system_prompt = """
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

# Note: In a real application, we would use the actual LLMAgent.Flows API
# We'd create a flow with the tools and system prompt, then run the flow
# For example:
# {flow, initial_state} = LLMAgent.Flows.conversation(system_prompt, tools)
# AgentForge.run(flow, initial_state, user_message: "Create a retirement ETF portfolio for me.")

# Demonstrates using LLMAgent for investment portfolio tasks
defmodule LLMAgent.Examples.InvestmentDemo do
  @moduledoc """
  Demonstrates how LLMAgent can handle multi-step investment portfolio workflows.
  """
  
  @doc """
  Run the investment portfolio demo, showing the agent creating a portfolio based on user input
  and then adjusting it based on risk tolerance changes.
  """
  def run do
    IO.puts("\n=== Investment Portfolio Example ===\n")
    IO.puts("User: Create a retirement ETF portfolio for me.\n")
    
    # Simulate processing a portfolio creation request
    process_portfolio_creation()
    
    IO.puts("\nUser: Can you reduce the risk level? I'm concerned about market volatility.\n")
    # Simulate processing a risk adjustment request
    process_risk_adjustment("Lower")
    
    IO.puts("\n=== Example Complete ===")
    IO.puts("This example demonstrates how LLMAgent enables dynamic, multi-step workflows")
    IO.puts("that adapt based on user input and intermediate results.")
    IO.puts("")
    IO.puts("Try modifying the example to:")
    IO.puts("1. Request an aggressive portfolio instead")
    IO.puts("2. Add additional tools for tax analysis or retirement planning")
    IO.puts("3. Implement more sophisticated portfolio construction logic")
  end
  
  # Simulate the multi-step portfolio creation process
  defp process_portfolio_creation do
    IO.puts("--- Stage 1: ETF Screening ---")
    IO.puts("Assistant thinking: I should first screen for suitable ETFs...")
    
    # Simulate ETF screening
    etf_results = InvestmentTools.screen_etfs(%{})
    IO.puts("Found #{length(etf_results.etfs)} ETFs suitable for a retirement portfolio.")
    
    # Continue to portfolio construction
    process_portfolio_construction(etf_results.etfs)
  end
  
  # Simulate portfolio construction
  defp process_portfolio_construction(etfs) do
    IO.puts("\n--- Stage 2: Portfolio Construction ---")
    IO.puts("Assistant thinking: Now I'll construct a balanced portfolio...")
    
    # Create portfolio with moderate risk - we don't need to extract tickers separately
    # since the create_portfolio function handles that
    portfolio = InvestmentTools.create_portfolio(etfs, "Moderate")
    
    IO.puts("Created a moderate risk portfolio with expected return of #{Float.round(portfolio.expected_return, 2)}%")
    IO.puts("Allocations:")
    
    Enum.each(portfolio.allocations, fn alloc ->
      IO.puts("  #{alloc.ticker}: #{Float.round(alloc.allocation * 100, 1)}%")
    end)
    
    # Continue to backtesting
    process_portfolio_backtesting(portfolio)
  end
  
  # Simulate portfolio backtesting
  defp process_portfolio_backtesting(portfolio) do
    IO.puts("\n--- Stage 3: Portfolio Backtesting ---")
    IO.puts("Assistant thinking: Let me evaluate the historical performance...")
    
    # Run backtest for 10 years
    backtest = InvestmentTools.backtest_portfolio(portfolio, 10)
    
    IO.puts("Backtest Results (10 years):")
    IO.puts("  Initial investment: $#{Float.round(backtest.initial_investment, 2)}")
    IO.puts("  Final value: $#{Float.round(backtest.final_value, 2)}")
    IO.puts("  CAGR: #{Float.round(backtest.cagr, 2)}%")
    IO.puts("  Sharpe ratio: #{Float.round(backtest.sharpe_ratio, 2)}")
    IO.puts("  Max drawdown: #{Float.round(backtest.max_drawdown, 2)}%")
    
    # Provide a final response
    IO.puts("\nAssistant: I've created a moderate risk retirement portfolio for you with an expected annual return of #{Float.round(portfolio.expected_return, 2)}%. The portfolio consists of a diversified mix of ETFs including US stocks, international stocks, and bonds. Based on historical backtesting over 10 years, an initial investment of $100 would have grown to $#{Float.round(backtest.final_value, 2)}, with a compound annual growth rate of #{Float.round(backtest.cagr, 2)}%. Would you like me to adjust the risk level or make any other changes to this portfolio?")
  end
  
  # Simulate portfolio risk adjustment
  defp process_risk_adjustment(risk_direction) do
    IO.puts("--- Risk Adjustment Stage ---")
    IO.puts("Assistant thinking: The user wants to #{String.downcase(risk_direction)} the risk level. I need to retrieve the current portfolio from our conversation...")
    
    # Create a moderate portfolio as starting point
    etfs = InvestmentTools.screen_etfs(%{})[:etfs]
    current_portfolio = InvestmentTools.create_portfolio(etfs, "Moderate")
    
    IO.puts("Current portfolio has a #{current_portfolio.risk_profile} risk profile with expected return of #{Float.round(current_portfolio.expected_return, 2)}%")
    
    # Optimize the portfolio based on risk direction
    optimized = InvestmentTools.optimize_portfolio(current_portfolio, %{"risk_tolerance" => risk_direction})
    
    IO.puts("Optimized portfolio to #{optimized.risk_profile} risk profile with expected return of #{Float.round(optimized.expected_return, 2)}%")
    IO.puts("New allocations:")
    
    Enum.each(optimized.allocations, fn alloc ->
      IO.puts("  #{alloc.ticker}: #{Float.round(alloc.allocation * 100, 1)}%")
    end)
    
    # Final response after optimization
    IO.puts("\nAssistant: I've adjusted your portfolio to a #{String.downcase(optimized.risk_profile)} risk profile as requested. The expected annual return is now #{Float.round(optimized.expected_return, 2)}%. I've #{if risk_direction == "Lower", do: "increased", else: "reduced"} the allocation to bonds and #{if risk_direction == "Lower", do: "reduced", else: "increased"} exposure to equities, particularly #{if risk_direction == "Higher", do: "emerging markets", else: ""}. This change should provide #{if risk_direction == "Lower", do: "more stability with somewhat lower returns", else: "potentially higher returns with increased volatility"}. Is this more aligned with your preferences?")
  end
  

end

# Process the original user message
IO.puts("\n=== Investment Portfolio Example ===")
IO.puts("\nUser: Create a retirement ETF portfolio for me.")

# Run the demo
LLMAgent.Examples.InvestmentDemo.run()

# Add a prompt to the end to experiment with the example
IO.puts("\n=== Example Complete ===")
IO.puts("This example demonstrates how LLMAgent enables dynamic, multi-step workflows")
IO.puts("that adapt based on user input and intermediate results.")
IO.puts("")
IO.puts("Try modifying the example to:")
IO.puts("1. Request an aggressive portfolio instead")
IO.puts("2. Add additional tools for tax analysis or retirement planning")
IO.puts("3. Implement more sophisticated portfolio construction logic")
