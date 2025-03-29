defmodule LLMAgent.ExamplesTest do
  use ExUnit.Case, async: false

  # Disable these tests by default as they're more for demonstration
  # Enable by setting the environment variable: INCLUDE_EXAMPLES=true
  @moduletag :examples

  describe "investment_portfolio.exs" do
    @tag :example
    test "can run the investment portfolio example" do
      if System.get_env("INCLUDE_EXAMPLES") == "true" do
        # Capture the output to verify it runs without errors
        output =
          ExUnit.CaptureIO.capture_io(fn ->
            Code.eval_file("examples/investment_portfolio.exs")
          end)

        # Assert that key sections appear in the output
        assert String.contains?(output, "ETF Screening")
        assert String.contains?(output, "Portfolio Construction")
        assert String.contains?(output, "Backtest Results")
        assert String.contains?(output, "Risk Adjustment Stage")
      else
        # Skip test
        :ok
      end
    end
  end
end
