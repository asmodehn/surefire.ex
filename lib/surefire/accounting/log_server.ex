defmodule Surefire.Accounting.LogServer do
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
  # TODO : maybe GenStage is more appropriate here ???

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

  def chunk(pid, opts \\ [from: nil, until: nil]) do
    # TODO : Stream instead ??
    ftid = Keyword.get(opts, :from)
    utid = Keyword.get(opts, :until)

    GenServer.call(pid, {:chunk, ftid, utid})
  end

  def last_committed(pid) do
    GenServer.call(pid, {:last_committed})
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
  def handle_call({:chunk, from_tid, until_tid}, _from, history) do
    chunk = history |> History.chunk(from: from_tid, until: until_tid)

    {:reply, chunk, history}
  end

  @impl true
  def handle_call({:last_committed}, _from, history) do
    {:reply, history.last_committed_id, history}
  end
end
