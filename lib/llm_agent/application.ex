defmodule LLMAgent.Application do
  @moduledoc """
  The LLMAgent Application module.
  Starts the supervisor tree and manages the application lifecycle.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Define supervisors and worker processes here
    ]

    opts = [strategy: :one_for_one, name: LLMAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
