# Investment Portfolio Agent Example
#
# This example demonstrates a sophisticated LLM-powered investment advisor agent.
# It showcases dynamic workflow generation, tool chaining, and state management
# for complex workflows that adapt to user requests and analysis results.
#
# Key concepts demonstrated:
# 1. Dynamic workflow generation based on evolving context
# 2. Intelligent tool selection and sequencing
# 3. Multi-branch decision paths based on data
# 4. State management via Store interface
# 5. Error recovery strategies
#
# Run with: mix run examples/investment_portfolio.exs

defmodule MockInvestmentProvider do
  @moduledoc """
  Mock LLM provider that demonstrates dynamic workflow generation for investment analysis.

  This provider simulates an LLM making intelligent decisions based on:
  - Current portfolio state
  - Historical analysis results
  - Market conditions
  - Client risk preferences
  - Previous tool execution outcomes

  Unlike static DAG workflows, it dynamically chooses the next steps based on
  the evolving context and state.
  """

  require Logger

  @doc """
  Generate a response based on the current conversation state.
  Dynamically decides which tools to use based on previous tool results and user input.
  """
  def generate_response(messages, _opts \\ []) do
    # 1. Extract key information from conversation history
    last_user_message = get_last_user_message(messages)
    tool_results = get_tool_results(messages)

    # 2. Determine conversation state and context
    context = build_conversation_context(last_user_message, tool_results)

    # 3. Log detailed analysis for debugging
    Logger.debug("Analyzing conversation context: #{inspect(context)}")

    # 4. Make dynamic workflow decisions based on context
    cond do
      # INITIAL PORTFOLIO ANALYSIS PATH
      # Start a new portfolio analysis if we haven't run the ETF screener yet
      # and the user is asking about portfolio creation
      context.is_new_portfolio_request and not context.has_etf_data ->
        Logger.info("Starting new portfolio analysis workflow")

        # Dynamic behavior: Choose initial analysis approach based on question content
        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I'll analyze available investment options for your #{context.risk_profile} risk profile.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "etf_screener",
                       "arguments" =>
                         Jason.encode!(%{
                           "risk_level" => context.risk_level,
                           "category" => determine_category(last_user_message)
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # PORTFOLIO CONSTRUCTION PATH
      # After ETF screening, create the portfolio if not done yet
      context.has_etf_data and not context.has_portfolio ->
        Logger.info("Proceeding to portfolio construction phase")

        # Extract ETFs from screener results for portfolio construction
        etfs = extract_etfs(context.screener_result)

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "Based on the available ETFs, I'll construct a #{context.risk_profile} portfolio for you.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "portfolio_constructor",
                       "arguments" =>
                         Jason.encode!(%{
                           "risk_profile" => context.risk_profile,
                           "etfs" => etfs
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # PORTFOLIO EVALUATION PATH
      # After constructing the portfolio, perform backtesting
      context.has_portfolio and not context.has_backtest and should_backtest?(last_user_message) ->
        Logger.info("Portfolio constructed, proceeding to backtesting")

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "Let me evaluate how this portfolio would have performed historically.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "portfolio_backtester",
                       "arguments" =>
                         Jason.encode!(%{
                           "portfolio" => context.portfolio,
                           "years" => 10
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # OPTIMIZATION PATHS - Multiple potential branches based on context
      # Dynamic branching based on risk adjustment requests
      context.has_portfolio and context.risk_adjustment_requested ->
        Logger.info("Risk adjustment requested, optimizing portfolio")

        # Determine optimization direction based on request
        risk_preference = determine_risk_preference(last_user_message, context.risk_profile)

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "I'll adjust the portfolio to #{risk_preference} risk level.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "portfolio_optimizer",
                       "arguments" =>
                         Jason.encode!(%{
                           "portfolio" => context.portfolio,
                           "preferences" => %{
                             "risk_tolerance" => risk_preference
                           }
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # PORTFOLIO ANALYSIS PATH
      # When we have a complete portfolio with backtest and user wants analysis
      context.has_portfolio and context.has_backtest and context.analysis_requested ->
        Logger.info(
          "Comprehensive analysis requested after portfolio construction and backtesting"
        )

        # Generate comprehensive analysis without additional tool calls
        portfolio = context.portfolio
        backtest = context.backtest

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => generate_portfolio_analysis(portfolio, backtest)
               }
             }
           ]
         }}

      # MARKET SCENARIO ANALYSIS PATH
      # Simulate market conditions when requested
      context.has_portfolio and context.market_scenario_requested ->
        Logger.info("Market scenario analysis requested")

        # Dynamically choose which simulation to run based on the request
        scenario_type = determine_scenario_type(last_user_message)

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I'll simulate how your portfolio might perform during a #{scenario_type} market.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "market_simulator",
                       "arguments" =>
                         Jason.encode!(%{
                           "portfolio" => context.portfolio,
                           "scenario" => scenario_type
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # ERROR RECOVERY PATH
      # When a previous tool has failed and we need to recover
      context.has_error ->
        Logger.info("Recovering from previous error: #{context.error_message}")

        # Different recovery strategies based on which tool failed
        case context.failed_tool do
          "portfolio_constructor" ->
            {:ok,
             %{
               "choices" => [
                 %{
                   "message" => %{
                     "content" =>
                       "I encountered an issue creating your portfolio. Let me try with a different approach.",
                     "tool_calls" => [
                       %{
                         "function" => %{
                           "name" => "portfolio_constructor",
                           "arguments" =>
                             Jason.encode!(%{
                               "risk_profile" => context.risk_profile,
                               # Simplified fallback
                               "etfs" => ["VTI", "BND"],
                               "fallback" => true
                             })
                         }
                       }
                     ]
                   }
                 }
               ]
             }}

          _ ->
            {:ok,
             %{
               "choices" => [
                 %{
                   "message" => %{
                     "content" =>
                       "I encountered an issue in my analysis. Let me summarize what I know so far.",
                     "content_only" => true
                   }
                 }
               ]
             }}
        end

      # DEFAULT INFORMATIONAL RESPONSE
      # When no specific tool action is needed
      true ->
        Logger.info("Providing informational response")

        # Generate a contextual response based on what we know
        content = generate_contextual_response(context, last_user_message)

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => content
               }
             }
           ]
         }}
    end
  end

  #
  # Context building functions
  #

  defp get_last_user_message(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find(fn msg ->
      is_map(msg) and (msg["role"] == "user" or msg[:role] == "user")
    end)
    |> case do
      nil -> ""
      %{"content" => content} -> content
      %{content: content} -> content
      _ -> ""
    end
  end

  defp get_tool_results(messages) do
    messages
    |> Enum.filter(fn msg ->
      is_map(msg) and (msg["role"] == "function" or msg[:role] == "function")
    end)
    |> Enum.map(fn msg ->
      name = msg["name"] || msg[:name]
      content = msg["content"] || msg[:content]
      {name, Jason.decode!(content)}
    end)
    |> Map.new()
  end

  defp build_conversation_context(last_user_message, tool_results) do
    # Extract key state information
    question = String.downcase(last_user_message)

    # Get results from different tools if available
    screener_result = Map.get(tool_results, "etf_screener")
    portfolio = Map.get(tool_results, "portfolio_constructor")
    backtest = Map.get(tool_results, "portfolio_backtester")
    optimized = Map.get(tool_results, "portfolio_optimizer")

    # Detect the latest portfolio version
    latest_portfolio = optimized || portfolio

    # Identify conversation state
    %{
      # Data availability flags
      has_etf_data: screener_result != nil,
      has_portfolio: latest_portfolio != nil,
      has_backtest: backtest != nil,
      has_optimized: optimized != nil,

      # Request classification
      is_new_portfolio_request: is_new_portfolio_request?(question),
      risk_adjustment_requested: is_risk_adjustment_request?(question),
      analysis_requested: is_analysis_request?(question),
      market_scenario_requested: is_market_scenario_request?(question),

      # User preferences
      risk_profile: determine_risk_profile(question, latest_portfolio),
      risk_level: map_risk_profile_to_level(determine_risk_profile(question, latest_portfolio)),

      # Tool results for reference
      screener_result: screener_result,
      portfolio: latest_portfolio,
      backtest: backtest,

      # Error handling
      has_error: String.contains?(question, ["error", "fail", "issue", "problem"]),
      error_message:
        if(String.contains?(question, ["error", "fail", "issue", "problem"]),
          do: last_user_message,
          else: nil
        ),
      failed_tool:
        if(String.contains?(question, "portfolio construction"),
          do: "portfolio_constructor",
          else: nil
        )
    }
  end

  #
  # Decision and classification helper functions
  #

  defp is_new_portfolio_request?(question) do
    question = String.downcase(question)

    contains_keywords?(question, ["create", "build", "design", "new"]) and
      contains_keywords?(question, ["portfolio", "investment", "etf", "fund"])
  end

  defp is_risk_adjustment_request?(question) do
    question = String.downcase(question)

    contains_keywords?(question, ["risk", "aggressive", "conservative"]) and
      (contains_keywords?(question, [
         "adjust",
         "change",
         "modify",
         "increase",
         "decrease",
         "more",
         "less"
       ]) or
         contains_keywords?(question, [
           "too risky",
           "too safe",
           "too conservative",
           "too aggressive"
         ]))
  end

  defp is_analysis_request?(question) do
    question = String.downcase(question)

    contains_keywords?(question, [
      "analyze",
      "evaluate",
      "show",
      "explain",
      "detail",
      "tell me about"
    ]) or
      contains_keywords?(question, ["how would", "performance", "return", "history", "past"])
  end

  defp is_market_scenario_request?(question) do
    question = String.downcase(question)

    contains_keywords?(question, ["what if", "scenario", "crash", "bear", "bull", "recession"]) or
      contains_keywords?(question, ["downturn", "simulation", "crisis", "boom"])
  end

  defp determine_risk_profile(question, portfolio) do
    # If we already have a portfolio, use its risk profile as default
    default_profile = if portfolio, do: portfolio["risk_profile"], else: "Moderate"

    question = String.downcase(question)

    cond do
      contains_keywords?(question, ["conservative", "safe", "low risk", "cautious", "risk averse"]) ->
        "Conservative"

      contains_keywords?(question, ["aggressive", "high risk", "growth", "high return", "risky"]) ->
        "Aggressive"

      contains_keywords?(question, ["balanced", "moderate", "middle"]) ->
        "Moderate"

      true ->
        default_profile
    end
  end

  defp map_risk_profile_to_level(risk_profile) do
    case risk_profile do
      "Conservative" -> "Low"
      "Moderate" -> "Moderate"
      "Aggressive" -> "High"
      _ -> "Moderate"
    end
  end

  defp determine_risk_preference(question, _current_profile) do
    question = String.downcase(question)

    cond do
      contains_keywords?(question, [
        "safer",
        "lower risk",
        "less risk",
        "conservative",
        "too risky",
        "too aggressive"
      ]) ->
        "Lower"

      contains_keywords?(question, [
        "more risk",
        "higher risk",
        "aggressive",
        "growth",
        "too safe",
        "too conservative"
      ]) ->
        "Higher"

      true ->
        "Same"
    end
  end

  defp determine_category(question) do
    question = String.downcase(question)

    cond do
      contains_keywords?(question, ["tech", "technology", "innovation"]) -> "Technology"
      contains_keywords?(question, ["income", "dividend", "yield"]) -> "Income"
      contains_keywords?(question, ["global", "international", "worldwide"]) -> "International"
      contains_keywords?(question, ["esg", "sustainable", "green", "social"]) -> "ESG"
      true -> "Broad Market"
    end
  end

  defp determine_scenario_type(question) do
    question = String.downcase(question)

    cond do
      contains_keywords?(question, ["crash", "recession", "bear", "crisis", "down"]) ->
        "Bear Market"

      contains_keywords?(question, ["boom", "bull", "growth", "up", "recovery"]) ->
        "Bull Market"

      contains_keywords?(question, ["inflation", "rising rates", "interest"]) ->
        "High Inflation"

      contains_keywords?(question, ["volatility", "uncertainty"]) ->
        "High Volatility"

      # Default to stress test
      true ->
        "Bear Market"
    end
  end

  #
  # Response generation functions
  #

  defp generate_contextual_response(context, _question) do
    cond do
      context.has_portfolio and context.has_backtest ->
        portfolio = context.portfolio
        backtest = context.backtest

        "Based on our analysis, your #{String.downcase(portfolio["risk_profile"])} portfolio " <>
          "has an expected return of #{Float.round(portfolio["expected_return"], 2)}%. " <>
          "The historical analysis shows a compound annual growth rate of #{Float.round(backtest["cagr"], 2)}% " <>
          "with a maximum drawdown of #{Float.round(backtest["max_drawdown"], 2)}%. " <>
          "Would you like me to adjust the risk level or analyze specific market scenarios?"

      context.has_portfolio ->
        portfolio = context.portfolio

        "I've created a #{String.downcase(portfolio["risk_profile"])} risk portfolio " <>
          "with an expected return of #{Float.round(portfolio["expected_return"], 2)}%. " <>
          "The portfolio consists of #{length(portfolio["allocations"])} ETFs. " <>
          "Would you like me to run a historical performance analysis on this portfolio?"

      context.has_etf_data ->
        screener = context.screener_result

        "I've found #{screener["count"]} ETFs that match your criteria. " <>
          "Would you like me to construct a portfolio using these funds?"

      true ->
        "I can help you create and analyze an investment portfolio. " <>
          "Would you like me to recommend a portfolio based on your risk preference?"
    end
  end

  defp generate_portfolio_analysis(portfolio, backtest) do
    """
    I've completed a comprehensive analysis of your #{String.downcase(portfolio["risk_profile"])} risk portfolio.

    Portfolio Composition:
    #{format_allocations(portfolio["allocations"])}

    Expected Annual Return: #{Float.round(portfolio["expected_return"], 2)}%

    Historical Performance (#{backtest["years"]} years):
    - Compound Annual Growth Rate (CAGR): #{Float.round(backtest["cagr"], 2)}%
    - Risk-adjusted Return (Sharpe Ratio): #{Float.round(backtest["sharpe_ratio"], 2)}
    - Maximum Drawdown: #{Float.round(backtest["max_drawdown"], 2)}%

    This portfolio offers a balance of #{cond do
      portfolio["risk_profile"] == "Conservative" -> "capital preservation and modest income"
      portfolio["risk_profile"] == "Aggressive" -> "growth potential with higher volatility"
      true -> "growth and stability"
    end}.

    Would you like me to adjust the risk level or test how this portfolio might perform in specific market scenarios?
    """
  end

  #
  # Utility functions
  #

  defp contains_keywords?(text, keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end

  defp extract_etfs(screener_result) do
    Enum.map(screener_result["etfs"], & &1["ticker"])
  end

  defp format_allocations(allocations) do
    allocations
    |> Enum.map(fn alloc ->
      "- #{alloc["ticker"]}: #{Float.round(alloc["allocation"] * 100, 1)}%"
    end)
    |> Enum.join("\n")
  end

  defp should_backtest?(question) do
    question = String.downcase(question)

    contains_keywords?(question, [
      "perform",
      "history",
      "backtest",
      "historical",
      "show me",
      "analysis"
    ]) or
      contains_keywords?(question, ["how would", "how has", "past", "over time"])
  end
end

defmodule LLMAgent.Examples.InvestmentTools do
  @moduledoc """
  Provides investment analysis tools for the portfolio advisor agent.
  """

  def get_tools do
    [
      %{
        name: "etf_screener",
        description: "Screen ETFs based on criteria",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "risk_level" => %{
              "type" => "string",
              "enum" => ["Low", "Moderate", "High"]
            },
            "category" => %{
              "type" => "string"
            }
          }
        },
        execute: &screen_etfs/1
      },
      %{
        name: "portfolio_constructor",
        description: "Create a portfolio from ETFs",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "risk_profile" => %{
              "type" => "string",
              "enum" => ["Conservative", "Moderate", "Aggressive"]
            },
            "etfs" => %{
              "type" => "array",
              "items" => %{
                "type" => "string"
              }
            }
          },
          "required" => ["risk_profile"]
        },
        execute: &create_portfolio/1
      },
      %{
        name: "portfolio_backtester",
        description: "Backtest a portfolio",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "portfolio" => %{
              "type" => "object"
            },
            "years" => %{
              "type" => "integer"
            }
          },
          "required" => ["portfolio"]
        },
        execute: &backtest_portfolio/1
      },
      %{
        name: "portfolio_optimizer",
        description: "Optimize a portfolio",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "portfolio" => %{
              "type" => "object"
            },
            "preferences" => %{
              "type" => "object"
            }
          },
          "required" => ["portfolio", "preferences"]
        },
        execute: &optimize_portfolio/1
      },
      %{
        name: "market_simulator",
        description: "Simulate portfolio performance in different market scenarios",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "portfolio" => %{
              "type" => "object"
            },
            "scenario" => %{
              "type" => "string",
              "enum" => ["Bear Market", "Bull Market", "High Inflation", "High Volatility"]
            }
          },
          "required" => ["portfolio", "scenario"]
        },
        execute: &simulate_market_scenario/1
      }
    ]
  end

  # Tool implementation functions
  def screen_etfs(%{"risk_level" => risk_level, "category" => category}) do
    # Mock ETF data
    all_etfs = [
      %{
        ticker: "VTI",
        name: "Vanguard Total Stock Market ETF",
        expense_ratio: 0.03,
        category: "Broad Market",
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
        category: "International",
        risk_level: "Moderate-High",
        avg_return: 8.1
      },
      %{
        ticker: "VGT",
        name: "Vanguard Information Technology ETF",
        expense_ratio: 0.10,
        category: "Technology",
        risk_level: "High",
        avg_return: 15.3
      },
      %{
        ticker: "SCHD",
        name: "Schwab US Dividend Equity ETF",
        expense_ratio: 0.06,
        category: "Income",
        risk_level: "Moderate",
        avg_return: 9.2
      },
      %{
        ticker: "ESGV",
        name: "Vanguard ESG U.S. Stock ETF",
        expense_ratio: 0.09,
        category: "ESG",
        risk_level: "Moderate",
        avg_return: 9.8
      }
    ]

    # Filter based on criteria
    etfs =
      all_etfs
      |> Enum.filter(fn etf ->
        (category == "Broad Market" or etf.category == category) and
          (risk_level == "Moderate" or etf.risk_level == risk_level or
             String.contains?(etf.risk_level, risk_level))
      end)

    %{
      etfs: etfs,
      count: length(etfs)
    }
  end

  def create_portfolio(%{"risk_profile" => risk_profile} = params) do
    # Check if we're in fallback mode (error recovery)
    fallback = Map.get(params, "fallback", false)

    # Use ETFs provided in request or default set
    _provided_etfs = Map.get(params, "etfs", nil)

    allocations =
      case {risk_profile, fallback} do
        {"Conservative", true} ->
          [
            %{ticker: "BND", allocation: 0.8},
            %{ticker: "VTI", allocation: 0.2}
          ]

        {"Conservative", false} ->
          [
            %{ticker: "BND", allocation: 0.6},
            %{ticker: "VTI", allocation: 0.3},
            %{ticker: "VEA", allocation: 0.1}
          ]

        {"Moderate", true} ->
          [
            %{ticker: "VTI", allocation: 0.5},
            %{ticker: "BND", allocation: 0.5}
          ]

        {"Moderate", false} ->
          [
            %{ticker: "VTI", allocation: 0.6},
            %{ticker: "BND", allocation: 0.3},
            %{ticker: "VEA", allocation: 0.1}
          ]

        {"Aggressive", true} ->
          [
            %{ticker: "VTI", allocation: 0.9},
            %{ticker: "BND", allocation: 0.1}
          ]

        {"Aggressive", false} ->
          [
            %{ticker: "VTI", allocation: 0.7},
            %{ticker: "VEA", allocation: 0.2},
            %{ticker: "BND", allocation: 0.1}
          ]
      end

    expected_return = calculate_expected_return(allocations)

    %{
      allocations: allocations,
      risk_profile: risk_profile,
      expected_return: expected_return
    }
  end

  def backtest_portfolio(%{"portfolio" => portfolio, "years" => years}) do
    # Mock backtest results based on portfolio risk profile
    years = years || 10

    # Adjust based on risk profile
    {cagr, max_drawdown, sharpe_ratio} =
      case portfolio["risk_profile"] do
        "Conservative" -> {5.2, 10.0, 0.65}
        "Moderate" -> {8.2, 20.0, 0.75}
        "Aggressive" -> {11.5, 35.0, 0.82}
        _ -> {8.2, 20.0, 0.75}
      end

    %{
      years: years,
      initial_investment: 100.0,
      final_value: calculate_final_value(100.0, cagr, years),
      cagr: cagr,
      max_drawdown: max_drawdown,
      sharpe_ratio: sharpe_ratio,
      risk_adjusted_return: sharpe_ratio * 100.0
    }
  end

  def backtest_portfolio(%{"portfolio" => portfolio}) do
    # Default to 10 years when not specified
    backtest_portfolio(%{"portfolio" => portfolio, "years" => 10})
  end

  def optimize_portfolio(%{
        "portfolio" => portfolio,
        "preferences" => %{"risk_tolerance" => risk_tolerance}
      }) do
    current_profile = portfolio["risk_profile"]

    new_profile =
      case {current_profile, risk_tolerance} do
        {"Aggressive", "Lower"} -> "Moderate"
        {"Moderate", "Lower"} -> "Conservative"
        {"Conservative", "Higher"} -> "Moderate"
        {"Moderate", "Higher"} -> "Aggressive"
        _ -> current_profile
      end

    create_portfolio(%{"risk_profile" => new_profile})
  end

  def simulate_market_scenario(%{"portfolio" => portfolio, "scenario" => scenario}) do
    base_return = portfolio["expected_return"]

    # Simulate different market scenarios
    {return_impact, volatility_impact, max_drawdown} =
      case scenario do
        "Bear Market" -> {-0.25, 1.5, 0.35}
        "Bull Market" -> {0.15, 0.8, 0.12}
        "High Inflation" -> {-0.1, 1.2, 0.18}
        "High Volatility" -> {0.0, 2.0, 0.25}
        _ -> {0.0, 1.0, 0.15}
      end

    # Calculate scenario performance
    scenario_return = base_return * (1 + return_impact)

    %{
      scenario: scenario,
      expected_return: scenario_return,
      volatility_multiplier: volatility_impact,
      max_drawdown: max_drawdown * 100,
      summary: generate_scenario_summary(scenario, scenario_return, portfolio["risk_profile"])
    }
  end

  # Helper functions
  defp calculate_expected_return(allocations) do
    returns = %{
      "VTI" => 10.2,
      "BND" => 3.8,
      "VEA" => 8.1,
      "VGT" => 15.3,
      "SCHD" => 9.2,
      "ESGV" => 9.8
    }

    Enum.reduce(allocations, 0, fn alloc, acc ->
      # Default if ticker unknown
      ticker_return = Map.get(returns, alloc.ticker, 7.0)
      acc + ticker_return * alloc.allocation
    end)
  end

  defp calculate_final_value(initial, cagr, years) do
    initial * :math.pow(1 + cagr / 100, years)
  end

  defp generate_scenario_summary(scenario, return, risk_profile) do
    case scenario do
      "Bear Market" ->
        "In a bear market, your #{String.downcase(risk_profile)} portfolio would be expected " <>
          "to lose value, with returns dropping to around #{Float.round(return, 1)}%. " <>
          "#{if risk_profile == "Conservative",
            do: "The higher bond allocation would provide some protection.",
            else: "The equity-heavy allocation would result in significant drawdowns."}"

      "Bull Market" ->
        "In a bull market, your #{String.downcase(risk_profile)} portfolio would likely " <>
          "perform well, with returns potentially reaching #{Float.round(return, 1)}%. " <>
          "#{if risk_profile == "Aggressive",
            do: "The higher equity allocation would capture most of the upside.",
            else: "The conservative allocation would limit some of the potential gains."}"

      "High Inflation" ->
        "During high inflation, your #{String.downcase(risk_profile)} portfolio would face challenges, " <>
          "with real returns potentially dropping to #{Float.round(return, 1)}%. " <>
          "#{if risk_profile == "Conservative",
            do: "Bond values may be particularly affected by rising rates.",
            else: "Equities may provide some inflation protection over the long term."}"

      "High Volatility" ->
        "In a highly volatile market, your #{String.downcase(risk_profile)} portfolio would experience " <>
          "significant price swings, though long-term returns might still average #{Float.round(return, 1)}%. " <>
          "#{if risk_profile == "Conservative",
            do: "The higher bond allocation would dampen some volatility.",
            else: "The equity-heavy allocation would result in dramatic price movements."}"

      _ ->
        "Under this scenario, your portfolio's expected return would be approximately #{Float.round(return, 1)}%."
    end
  end
end

defmodule LLMAgent.Examples.InvestmentDemo do
  @moduledoc """
  Demonstrates a sophisticated investment portfolio advisor built with LLMAgent.
  This example showcases dynamic workflow generation based on client needs,
  complex tool chaining, state management, and error recovery.
  """

  alias LLMAgent.{Flows, Signals, Store}

  require Logger

  def run do
    # 1. Configure LLMAgent to use our mock provider
    Application.put_env(:llm_agent, :provider, MockInvestmentProvider)

    # 2. Create store for this example with unique name
    store_name = :"investment_advisor_store_#{System.unique_integer([:positive])}"
    {:ok, _store_pid} = Store.start_link(name: store_name)

    # 3. Store initial state using the Store interface
    Store.put(store_name, :market_volatility, "Normal")
    Store.put(store_name, :interest_rate_trend, "Stable")
    Store.put(store_name, :economic_outlook, "Mixed")
    Store.put(store_name, :analysis_depth, "Comprehensive")

    # 4. Create system prompt for investment advisor
    system_prompt = """
    You are an investment advisor specializing in ETF portfolios.

    Follow a dynamic analysis approach based on client needs:
    1. Screen ETFs based on client preferences and market conditions
    2. Construct a portfolio aligned with risk profile and goals
    3. Analyze historical performance using backtesting
    4. Optimize the portfolio based on client feedback
    5. Simulate performance in different market scenarios

    When providing recommendations, consider:
    - Current market conditions: #{elem(Store.get(store_name, :market_volatility), 1)}
    - Interest rate environment: #{elem(Store.get(store_name, :interest_rate_trend), 1)}
    - Economic outlook: #{elem(Store.get(store_name, :economic_outlook), 1)}

    Tailor your analysis approach to the client's knowledge level and goals.
    Present your findings clearly with both technical detail and plain language explanations.
    """

    # 5. Create conversation flow with investment tools
    {flow, _fresh_state} =
      Flows.tool_agent(
        system_prompt,
        LLMAgent.Examples.InvestmentTools.get_tools(),
        store_name: store_name
      )

    # 6. Demo intro
    IO.puts("\n=== Investment Portfolio Advisor Example ===\n")
    IO.puts("This example demonstrates:")
    IO.puts("- Dynamic workflow generation based on client input")
    IO.puts("- Multi-step analysis with state tracking")
    IO.puts("- Conditional tool selection")
    IO.puts("- Error recovery and alternate path execution")
    IO.puts("- Context-aware responses\n")

    # 7. Process dynamic conversation scenarios
    sample_conversations = [
      # Scenario 1: Standard Portfolio Creation
      [
        "I'd like to create a retirement portfolio. I prefer moderate risk investments.",
        "Can you make it a bit more conservative? I'm worried about market volatility.",
        "Show me how this portfolio has performed historically."
      ],

      # Scenario 2: Specialized Portfolio with Market Scenarios
      [
        "I need a technology-focused aggressive portfolio for growth.",
        "What would happen to this portfolio during a market crash?",
        "Let's adjust it to be more balanced while maintaining tech exposure."
      ],

      # Scenario 3: Income Portfolio with Error Recovery
      [
        "I want a portfolio focused on dividend income for retirement.",
        # This will trigger error recovery path
        "error in portfolio construction",
        "What's the expected yield on this portfolio?"
      ]
    ]

    # Run each conversation scenario with a fresh state
    Enum.with_index(sample_conversations, 1)
    |> Enum.each(fn {conversation, index} ->
      # Reset store between scenarios
      reset_store(store_name)

      # Create new state for each conversation
      {_flow, fresh_state} =
        Flows.tool_agent(
          system_prompt,
          LLMAgent.Examples.InvestmentTools.get_tools(),
          store_name: store_name
        )

      IO.puts("\n\n=== Scenario #{index} ===\n")

      # Process each interaction in the conversation
      Enum.reduce(conversation, fresh_state, fn input, current_state ->
        IO.puts("\nClient: #{input}")

        # Create user message signal
        signal = Signals.user_message(input)

        # Process through the investment flow
        case flow.(signal, current_state) do
          {:emit, %{type: :response} = response_signal, new_state} ->
            display_response({:emit, response_signal})

            # Store conversation progress in the store for stateful decisions
            Store.put(store_name, :last_client_message, input)

            new_state

          {:emit, %{type: :tool_result} = tool_signal, new_state} ->
            display_response({:emit, tool_signal})

            # Store tool result data
            store_result_data(store_name, {:emit, tool_signal})

            new_state

          {:error, error} ->
            IO.puts("Error: #{error}")

            # Store error for recovery paths
            Store.put(store_name, :last_error, error)

            current_state

          unexpected ->
            IO.puts("Unexpected result: #{inspect(unexpected)}")
            current_state
        end
      end)
    end)

    # 8. Demo conclusion with architectural insights
    IO.puts("\n=== Investment Agent Architecture ===")

    IO.puts("""
    This example demonstrates how LLMAgent builds dynamic workflows:

    1. Signal-Based Decision Making:
       The agent doesn't follow a predefined DAG, but instead makes decisions
       based on evolving context and conversation state.

    2. Tool Chaining with LLM Intelligence:
       Unlike rule-based systems, the agent intelligently chains tools based on:
       - Results of previous tool executions
       - Client request analysis
       - Contextual state information

    3. Dynamic Path Selection:
       The agent dynamically determines:
       - Which tool to use next
       - When to terminate tool chains
       - How to recover from errors
       - When to branch into alternative analysis paths

    4. State Management:
       The Store component maintains state across interactions:
       - State keys tracked for decision making
       - Analysis history preserved
       - Tool results maintained for context
    """)

    IO.puts("\n=== Example Complete ===")
    IO.puts("\nTo implement similar agents in your application, follow this pattern:")

    IO.puts("""
    1. Define domain-specific tools:
    ```elixir
    tools = [
      %{
        name: "portfolio_analyzer",
        description: "Analyze investment portfolios based on risk profile and goals",
        parameters: %{
          type: "object",
          properties: %{
            risk_profile: %{type: "string", enum: ["Conservative", "Moderate", "Aggressive"]}
          }
        }
      }
    ]
    ```

    2. Initialize store and create the agent:
    ```elixir
    store_name = MyApp.InvestmentStore
    {flow, state} = LLMAgent.Flows.tool_agent(system_prompt, tools, store_name: store_name)
    ```

    3. Process client requests:
    ```elixir
    {result, new_state} = flow.(Signals.user_message(request), state)
    ```

    4. Access stateful information:
    ```elixir
    portfolio = Store.get(store_name, :current_portfolio)
    history = Store.get_llm_history(store_name)
    """)
  end

  # Helper functions for demo

  # Reset store between scenarios
  defp reset_store(store_name) do
    # Reset store but preserve specific keys
    preserved_keys = [
      :market_volatility,
      :interest_rate_trend,
      :economic_outlook,
      :analysis_depth
    ]

    # Save values we want to keep
    preserved_values =
      preserved_keys
      |> Enum.map(fn key -> {key, elem(Store.get(store_name, key), 1)} end)
      |> Map.new()

    IO.puts("\n--- Resetting conversation state ---\n")

    # We will simply reset the values we want to keep
    Enum.each(preserved_values, fn {key, value} ->
      Store.put(store_name, key, value)
    end)
  end

  # Store result data for stateful decisions
  defp store_result_data(store_name, {:emit, %{type: :tool_result} = signal}) do
    tool_name = signal.data.name
    result = signal.data.result

    # Store specific data based on tool type
    case tool_name do
      "portfolio_constructor" ->
        Store.put(store_name, :current_portfolio, result)
        Store.put(store_name, :risk_profile, result["risk_profile"])

      "portfolio_backtester" ->
        Store.put(store_name, :backtest_results, result)

      "portfolio_optimizer" ->
        Store.put(store_name, :current_portfolio, result)
        Store.put(store_name, :risk_profile, result["risk_profile"])

      "market_simulator" ->
        Store.put(store_name, :market_scenarios, [
          result | elem(Store.get(store_name, :market_scenarios), 1) || []
        ])

      _ ->
        :ok
    end
  end

  defp store_result_data(_store_name, _result), do: :ok

  # Display different types of responses
  defp display_response({:emit, %{type: :response} = signal}),
    do: IO.puts("Advisor: #{signal.data}")

  defp display_response({:emit, %{type: :tool_result} = signal}),
    do:
      IO.puts(
        "Analysis complete: #{format_tool_result(signal.data.name, Jason.encode!(signal.data.result))}"
      )

  defp _display_tool_call({:emit, %{type: :tool_call} = signal}),
    do: IO.puts("Running analysis: #{signal.data.name}")

  defp _display_error({:emit, %{type: :error} = signal}),
    do: IO.puts("Error: #{signal.data.message}")

  defp _display_halt({:halt, response}),
    do: IO.puts("Final response: #{inspect(response)}")

  defp _display_skip({:skip, _}), do: nil

  defp display_response(other), do: IO.puts("Unexpected response: #{inspect(other)}")

  # Format tool results for display
  defp format_tool_result("etf_screener", result) do
    result = Jason.decode!(result)

    """
    Found #{result["count"]} ETFs:
    #{Enum.map_join(result["etfs"], "\n", fn etf -> "- #{etf["ticker"]}: #{etf["name"]} (Risk: #{etf["risk_level"]})" end)}
    """
  end

  defp format_tool_result("portfolio_constructor", result) do
    result = Jason.decode!(result)

    """
    Created #{String.downcase(result["risk_profile"])} risk portfolio:
    #{Enum.map_join(result["allocations"], "\n", fn alloc -> "- #{alloc["ticker"]}: #{Float.round(alloc["allocation"] * 100, 1)}%" end)}
    Expected return: #{Float.round(result["expected_return"], 2)}%
    """
  end

  defp format_tool_result("portfolio_backtester", result) do
    result = Jason.decode!(result)

    """
    Backtest results (#{result["years"]} years):
    - Initial $100 grew to $#{Float.round(result["final_value"], 2)}
    - CAGR: #{Float.round(result["cagr"], 2)}%
    - Sharpe ratio: #{Float.round(result["sharpe_ratio"], 2)}
    - Max drawdown: #{Float.round(result["max_drawdown"], 2)}%
    """
  end

  defp format_tool_result("market_simulator", result) do
    result = Jason.decode!(result)

    """
    #{result["scenario"]} scenario:
    - Expected return: #{Float.round(result["expected_return"], 2)}%
    - Volatility: #{if result["volatility_multiplier"] > 1, do: "Increased", else: "Decreased"} (#{result["volatility_multiplier"]}x)
    - Maximum drawdown: #{Float.round(result["max_drawdown"], 1)}%

    #{result["summary"]}
    """
  end

  defp format_tool_result(tool_name, result) do
    "#{tool_name} result: #{result}"
  end
end

# Run the example
LLMAgent.Examples.InvestmentDemo.run()
