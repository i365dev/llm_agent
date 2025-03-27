ExUnit.start()

# Configure LLM providers to use mock implementations during tests
Application.put_env(:llm_agent, :provider_mode, :mock)
