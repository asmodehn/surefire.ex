defmodule Surefire.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Surefire.Worker.start_link(arg)
      # {Surefire.Worker, arg}
      Surefire.Accounting
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Surefire.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
