defmodule Surefire.LongRun do
  @moduledoc ~s"""
  A module to manage a sequence of games, along with long term probabilities, etc.
  """

  alias Surefire.Accounting.LedgerServer
  alias Surefire.Accounting.AccountID

  defstruct id: nil,
            ledger: nil,
            games: %{},
            games_counter: 0

  def new(id, initial_assets) do
    {:ok, ledger_pid} = GenServer.start_link(LedgerServer, Surefire.Accounting.LogServer)

    :ok = LedgerServer.open_account(ledger_pid, :liabilities, "External Liabilities", :credit)
    :ok = LedgerServer.open_account(ledger_pid, :assets, "Assets", :debit)

    LedgerServer.transfer_debit(
      ledger_pid,
      "Financing #{id} assets",
      :liabilities,
      :assets,
      initial_assets
    )

    %__MODULE__{
      id: id,
      ledger: ledger_pid
    }
  end

  # TODO : maybe a protocol, mimicing player code design ??
  def assets(%Surefire.LongRun{ledger: ledger_pid}) do
    %AccountID{ledger_pid: ledger_pid, account_id: :assets}
  end

  def liabilities(%Surefire.LongRun{ledger: ledger_pid}) do
    %AccountID{ledger_pid: ledger_pid, account_id: :liabilities}
  end

  def account(%Surefire.LongRun{ledger: ledger_pid}, account_id)
      when is_atom(account_id) do
    %AccountID{ledger_pid: ledger_pid, account_id: account_id}
  end

  def new_game_server(longrun, game_server) do
    # TODO : game creation... <=> game_server process creation
  end

  def new_game(longrun, game) do
    # TODO : game creation... <=> game_server process creation
  end

  # TODO : play a series of (identical) games with one or more players...
  #  def play()
end
