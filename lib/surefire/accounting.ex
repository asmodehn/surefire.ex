defmodule Surefire.Accounting do
  @moduledoc ~s"""
  Accounting API for Surefire Players and Games.
  Also uses a Server to store the transaction history.

  Functions in this module represent different types of transactions, that needs to be:
  - created
  - recorded in history
  - represented (cached) in ledger accounts entries
  other functions to retrieve account balances, and deduce possible actions...



  """

  alias Surefire.Accounting.{History, Transaction}

  use GenServer
  # TODO : move history server into history module.
  # TODO : keep this module for friendly interface ( with implicit account reflection)

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  # TODO : various transaction creation depending on possible operations...
  def transfer(from_account, to_account, amount, pid \\ __MODULE__) do
    transaction =
      Transaction.build("Transfer #{amount} from #{from_account} to #{to_account}")
      |> Transaction.with_debit(from_account, amount)
      |> Transaction.with_credit(to_account, amount)

    # Note: transactions are safe to transfer around: atomic event-like / message-like
    tid = GenServer.call(pid, {:commit, transaction})

    tid
  end

  def transactions(pid, opts \\ [since: nil]) do
    # TODO : Stream instead ??
    stid = Keyword.get(opts, :since)
    GenServer.call(pid, {:transactions, stid})
  end

  # Server (callbacks)

  @impl true
  def init(_opts) do
    {:ok, History.new()}
  end

  @impl true
  def handle_call({:commit, transaction}, _from, history) do
    {tid, history} = History.new_transaction_id(history)
    {:ok, updated_history} = history |> History.commit(tid, transaction)
    {:reply, tid, updated_history}
  end

  @impl true
  def handle_call({:transactions, transaction_id}, _from, history) do
    ts =
      if is_nil(transaction_id) do
        history
      else
        history |> History.transactions_from(transaction_id)
      end

    {:reply, ts, history}
  end
end
