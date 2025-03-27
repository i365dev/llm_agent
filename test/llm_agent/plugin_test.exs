defmodule LLMAgent.PluginTest do
  @moduledoc """
  Tests for the LLMAgent.Plugin module.
  Verifies plugin initialization and LLM provider integration.
  """

  use ExUnit.Case

  describe "LLMAgent.Plugin" do
    setup do
      # Setup may be used for future tests
      :ok
    end

    test "module exists and can be loaded" do
      # Verify the module exists
      assert Code.ensure_loaded?(LLMAgent.Plugin)
    end

    test "initializes the plugin with a mock provider" do
      # Initialize with the mock provider for testing
      result = LLMAgent.Plugin.init(provider: :mock)

      # Should return :ok
      assert result == :ok
    end

    test "returns error for unsupported provider" do
      # Initialize with an unsupported provider
      result = LLMAgent.Plugin.init(provider: :unsupported)

      # Should return an error tuple
      assert match?({:error, _reason}, result)
    end

    test "returns metadata" do
      metadata = LLMAgent.Plugin.metadata()

      # Verify metadata structure
      assert is_map(metadata)
      assert Map.has_key?(metadata, :name)
      assert is_binary(metadata.name)
      assert String.contains?(metadata.name, "LLMAgent")
    end
  end
end
