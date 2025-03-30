# Investment Portfolio Agent Example
#
# This example demonstrates a sophisticated LLM-powered investment advisor agent.
# It showcases multi-step analysis, tool chaining, and state management
# for complex workflows.
#
# Key concepts demonstrated:
# 1. Complex tool interactions and chaining
# 2. Multi-step workflows with state persistence
# 3. Structured data handling
# 4. Error recovery in financial operations
#
# Run with: elixir investment_portfolio.exs

defmodule MockInvestmentProvider do
  @behaviour LLMAgent.Provider

  @impl true
  def generate_response(messages, _opts \\ []) do
    # Get conversation history and last message
    last_message =
      messages
      |> Enum.reverse()
      |> Enum.find(fn msg -> msg["role"] == "user" end)

    # Get function results from history
    function_results =
      messages
      |> Enum.filter(fn msg -> msg["role"] == "function" end)
      |> Enum.map(fn msg -> {msg["name"], Jason.decode!(msg["content"])} end)
      |> Map.new()

    question = last_message["content"]

    # Simulate LLM analysis and tool selection
    cond do
      # Initial portfolio creation flow
      not Map.has_key?(function_results, "etf_screener") and should_create_portfolio?(question) ->
        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "Let me analyze available ETFs for your portfolio.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "etf_screener",
                       "arguments" => Jason.encode!(%{})
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # Portfolio construction after ETF screening
      Map.has_key?(function_results, "etf_screener") and
          not Map.has_key?(function_results, "portfolio_constructor") ->
        risk_profile = determine_risk_profile(question)

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I've found suitable ETFs. Now let me construct a #{risk_profile} portfolio.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "portfolio_constructor",
                       "arguments" =>
                         Jason.encode!(%{
                           "risk_profile" => risk_profile,
                           "etfs" => extract_etfs(function_results["etf_screener"])
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # Backtest after portfolio construction
      Map.has_key?(function_results, "portfolio_constructor") and
          not Map.has_key?(function_results, "portfolio_backtester") ->
        portfolio = function_results["portfolio_constructor"]

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I'll run a backtest to evaluate this portfolio's historical performance.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "portfolio_backtester",
                       "arguments" =>
                         Jason.encode!(%{
                           "portfolio" => portfolio
                         })
                     }
                   }
                 ]
               }
             }
           ]
         }}

      # Portfolio optimization requests
      Map.has_key?(function_results, "portfolio_constructor") and
          risk_adjustment_requested?(question) ->
        current_portfolio = function_results["portfolio_constructor"]

        risk_preference =
          if String.contains?(question, ["lower", "reduce", "safer"]), do: "Lower", else: "Higher"

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I'll adjust the portfolio for #{String.downcase(risk_preference)} risk.",
                 "tool_calls" => [
                   %{
                     "function" => %{
                       "name" => "portfolio_optimizer",
                       "arguments" =>
                         Jason.encode!(%{
                           "portfolio" => current_portfolio,
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

      # Final analysis after getting all results
      Map.has_key?(function_results, "portfolio_backtester") ->
        portfolio = function_results["portfolio_constructor"]
        backtest = function_results["portfolio_backtester"]

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

      String.contains?(question, "error") ->
        {:error, "Simulated investment analysis error"}

      true ->
        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   "I need more information about your investment goals to assist you effectively.",
                 "role" => "assistant"
               }
             }
           ]
         }}
    end
  end

  # Helper functions for LLM decision simulation
  defp should_create_portfolio?(question) do
    question = String.downcase(question)
    String.contains?(question, ["portfolio", "invest", "etf"])
  end

  defp determine_risk_profile(question) do
    question = String.downcase(question)

    cond do
      String.contains?(question, ["conservative", "safe", "low risk"]) -> "Conservative"
      String.contains?(question, ["aggressive", "high risk", "growth"]) -> "Aggressive"
      true -> "Moderate"
    end
  end

  defp risk_adjustment_requested?(question) do
    question = String.downcase(question)

    String.contains?(question, ["risk"]) and
      String.contains?(question, ["lower", "higher", "reduce", "increase"])
  end

  defp extract_etfs(screener_result) do
    screener_result.etfs
    |> Enum.map(& &1.ticker)
  end

  defp generate_portfolio_analysis(portfolio, backtest) do
    """
    Based on my analysis, I've created a #{String.downcase(portfolio.risk_profile)} risk portfolio with an expected annual return of #{Float.round(portfolio.expected_return, 2)}%.

    Portfolio Allocation:
    #{format_allocations(portfolio.allocations)}

    Backtest Results (#{backtest.years} years):
    - Initial investment: $#{Float.round(backtest.initial_investment, 2)}
    - Final value: $#{Float.round(backtest.final_value, 2)}
    - CAGR: #{Float.round(backtest.cagr, 2)}%
    - Sharpe ratio: #{Float.round(backtest.sharpe_ratio, 2)}
    - Maximum drawdown: #{Float.round(backtest.max_drawdown, 2)}%

    Would you like me to adjust the portfolio's risk level or make any other changes?
    """
  end

  defp format_allocations(allocations) do
    allocations
    |> Enum.map(fn alloc -> "- #{alloc.ticker}: #{Float.round(alloc.allocation * 100, 1)}%" end)
    |> Enum.join("\n")
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
      }
    ]
  end

  # Tool implementation functions
  def screen_etfs(_criteria) do
    # Mock ETF data
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
      }
    ]

    %{
      etfs: etfs,
      count: length(etfs)
    }
  end

  def create_portfolio(%{"risk_profile" => risk_profile}) do
    allocations =
      case risk_profile do
        "Conservative" ->
          [
            %{ticker: "BND", allocation: 0.6},
            %{ticker: "VTI", allocation: 0.3},
            %{ticker: "VEA", allocation: 0.1}
          ]

        "Moderate" ->
          [
            %{ticker: "VTI", allocation: 0.6},
            %{ticker: "BND", allocation: 0.3},
            %{ticker: "VEA", allocation: 0.1}
          ]

        "Aggressive" ->
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

  def backtest_portfolio(%{"portfolio" => portfolio}) do
    # Mock backtest results
    %{
      years: 10,
      initial_investment: 100.0,
      final_value: 220.0,
      cagr: 8.2,
      max_drawdown: 15.0,
      sharpe_ratio: 0.75,
      risk_adjusted_return: 75.0
    }
  end

  def optimize_portfolio(%{
        "portfolio" => portfolio,
        "preferences" => %{"risk_tolerance" => risk_tolerance}
      }) do
    current_profile = portfolio.risk_profile

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

  # Helper functions
  defp calculate_expected_return(allocations) do
    returns = %{
      "VTI" => 10.2,
      "BND" => 3.8,
      "VEA" => 8.1
    }

    Enum.reduce(allocations, 0, fn alloc, acc ->
      acc + returns[alloc.ticker] * alloc.allocation
    end)
  end
end

defmodule LLMAgent.Examples.InvestmentDemo do
  @moduledoc """
  Demonstrates a sophisticated investment portfolio advisor built with LLMAgent.
  """

  alias AgentForge.Flow
  alias LLMAgent.{Flows, Signals, Store}

  def run do
    # 1. Configure LLMAgent to use our mock provider
    Application.put_env(:llm_agent, :provider, MockInvestmentProvider)

    # 2. Create store for this example
    store_name = :"investment_advisor_store_#{System.unique_integer([:positive])}"
    _store = Store.start_link(name: store_name)

    # 3. Create system prompt for investment advisor
    system_prompt = """
    You are an investment advisor specializing in ETF portfolios.
    Follow these steps when creating portfolios:
    1. Screen available ETFs using etf_screener
    2. Create a portfolio with portfolio_constructor
    3. Evaluate performance with portfolio_backtester
    4. Optimize if needed with portfolio_optimizer

    Be thorough in your analysis and explain your recommendations clearly.
    """

    # 4. Create conversation flow with investment tools
    {flow, state} =
      Flows.tool_agent(
        system_prompt,
        LLMAgent.Examples.InvestmentTools.get_tools(),
        store_name: store_name
      )

    IO.puts("\n=== Investment Portfolio Advisor Example ===\n")
    IO.puts("This example demonstrates:")
    IO.puts("- Advanced tool chaining")
    IO.puts("- Multi-step analysis")
    IO.puts("- Portfolio optimization\n")

    # 5. Process example conversation
    sample_conversation = [
      "Create a retirement portfolio for me. I prefer moderate risk.",
      "Can you make it a bit more conservative? I'm worried about market volatility.",
      "Show me how this portfolio has performed historically.",
      "What's the expected return on this portfolio?"
    ]

    # Process each interaction while maintaining state
    state =
      Enum.reduce(sample_conversation, state, fn input, current_state ->
        IO.puts("\nClient: #{input}")

        # Create user message signal
        signal = Signals.user_message(input)

        # Process through the investment flow
        case Flow.process(flow, signal, current_state) do
          {result, new_state} ->
            display_response(result)
            new_state

          {:error, error} ->
            IO.puts("Error: #{error}")
            current_state
        end
      end)

    # 6. Show analysis history
    IO.puts("\n=== Investment Analysis Process ===")
    history = Store.get_llm_history(store_name)

    Enum.each(history, fn message ->
      case message do
        %{role: "system"} ->
          IO.puts("\nAdvisor System: #{message.content}")

        %{role: "user"} ->
          IO.puts("\nClient: #{message.content}")

        %{role: "assistant"} ->
          IO.puts("Advisor: #{message.content}")

        %{role: "function", name: name} ->
          IO.puts("\nAnalysis (#{name}):")
          IO.puts(format_tool_result(name, message.content))

        _ ->
          IO.puts("#{String.capitalize(message.role)}: #{message.content}")
      end
    end)

    IO.puts("\n=== Example Complete ===")

    IO.puts("""

    To use this in your own application:

    1. Define your investment tools:
       tools = [
         %{
           name: "etf_screener",
           description: "Screen ETFs based on criteria",
           parameters: %{...},
           execute: &screen_etfs/1
         }
       ]

    2. Initialize store and create investment advisor:
       store_name = MyApp.InvestmentStore
       Store.start_link(name: store_name)
       {flow, state} = LLMAgent.Flows.tool_agent(system_prompt, tools, store_name: store_name)

    3. Process client requests:
       {result, new_state} = AgentForge.Flow.process(flow, Signals.user_message(request), state)

    4. Handle responses:
       case result do
         {:emit, response} -> process_emit(response)
         {:halt, response} -> process_halt(response)
         {:skip, _} -> process_skip()
       end

    5. Get analysis history:
       history = LLMAgent.Store.get_llm_history(store_name)
    """)
  end

  # Display different types of responses
  defp display_response({:emit, %{type: :response} = signal}), do: IO.puts("Advisor: #{signal.data}")
  defp display_response({:emit, %{type: :tool_call} = signal}), do: IO.puts("Running analysis: #{signal.data.name}")
  defp display_response({:emit, %{type: :tool_result} = signal}), do: IO.puts("Analysis complete: #{format_tool_result(signal.data.name, Jason.encode!(signal.data.result))}")
  defp display_response({:emit, %{type: :error} = signal}), do: IO.puts("Error: #{signal.data.message}")
  defp display_response({:halt, response}), do: IO.puts("Final response: #{inspect(response)}")
  defp display_response({:skip, _}), do: nil
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
    - CAGR: #{Float.round(result["cagr"], 2)}%
    - Sharpe ratio: #{Float.round(result["sharpe_ratio"], 2)}
    - Max drawdown: #{Float.round(result["max_drawdown"], 2)}%
    """
  end

  defp format_tool_result(tool_name, result) do
    "#{tool_name} result: #{result}"
  end
end

# Run the example
LLMAgent.Examples.InvestmentDemo.run()
