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

  #
  # TODO
  #  defmodule State do
  #    defstruct history: %History{},
  #              chart: %Chart{},
  #  end

  defmodule UnknownAccounts do
    defexception message: "accounts are unknown", accounts: nil

    def message(exception) do
      # TODO : retrieve ledger / playername /gamename ... from pid
      "Accounts #{exception.accounts |> Kernel.inspect()} are unknown !"
    end
  end

  defmodule UnbalancedTransaction do
    defexception message: "Transaction is unbalanced", transaction: nil

    def message(exception) do
      "Transaction #{exception.transaction |> Kernel.inspect()} is unbalanced !"
    end
  end

  alias Surefire.Accounting.{History, Transaction}

  use GenServer

  # Client
  def start_link(history, opts \\ [])

  def start_link([], opts) do
    start_link(History.new(), opts)
  end

  def start_link(%History{} = history, opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, history, name: name)
  end

  # TODO : various transaction creation depending on possible operations...
  def commit(pid, %Transaction{debit: debits, credit: credits} = transaction)
      when map_size(debits) != 0 or map_size(credits) != 0 do
    # Note: transactions are safe to transfer around: atomic event-like / message-like
    case GenServer.call(pid, {:commit, transaction}) do
      {:error, %UnknownAccounts{} = ua} -> raise ua
      {:error, %UnbalancedTransaction{} = ut} -> raise ut
      {:ok, tid} -> tid
    end
  end

  def chunk(pid, opts \\ [from: nil, until: nil]) do
    # TODO : some kind of Stream instead ??
    ftid = Keyword.get(opts, :from)
    utid = Keyword.get(opts, :until)

    GenServer.call(pid, {:chunk, ftid, utid})
  end

  def last_committed(pid) do
    GenServer.call(pid, {:last_committed})
  end

  def open_account(pid, apid, aid) do
    GenServer.call(pid, {:open, apid, aid})
  end

  def close_account(pid, apid, aid) do
    GenServer.call(pid, {:close, apid, aid})
  end

  def accounts(pid, apid) do
    GenServer.call(pid, {:accounts, apid})
  end

  # Server (callbacks)

  @impl true
  def init(history) do
    {:ok, history}
  end

  @impl true
  def handle_call({:commit, transaction}, _from, history) do
    # history.accounts |> IO.inspect()

    absent_credited =
      Transaction.credited_accounts(transaction)
      |> Enum.map(fn {p, al} ->
        {p, Enum.reject(al, fn a -> a in Map.get(history.accounts, p, []) end)}
      end)
      |> Enum.reject(fn {_, al} -> al == [] end)
      |> Enum.into(%{})

    absent_debited =
      Transaction.debited_accounts(transaction)
      |> Enum.map(fn {p, al} ->
        {p, Enum.reject(al, fn a -> a in Map.get(history.accounts, p, []) end)}
      end)
      |> Enum.reject(fn {_, al} -> al == [] end)
      |> Enum.into(%{})

    cond do
      absent_credited != %{} ->
        #      IO.inspect(absent_credited)
        {:reply, {:error, %UnknownAccounts{accounts: absent_credited}}, history}

      absent_debited != %{} ->
        #      IO.inspect(absent_debited)
        {:reply, {:error, %UnknownAccounts{accounts: absent_debited}}, history}

      not Transaction.verify_balanced(transaction) ->
        {:reply, {:error, %UnbalancedTransaction{transaction: transaction}}, history}

      true ->
        {tid, history} = History.new_transaction_id(history)
        {:ok, updated_history} = history |> History.commit(tid, transaction)
        {:reply, {:ok, tid}, updated_history}
    end
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

  @impl true
  def handle_call({:open, apid, aid}, _from, history) do
    updated = history |> History.open_account(apid, aid)

    {:reply, :ok, updated}
  end

  @impl true
  def handle_call({:close, apid, aid}, _from, history) do
    updated = history |> History.close_account(apid, aid)

    {:reply, :ok, updated}
  end

  @impl true
  def handle_call({:accounts, apid}, _from, history) do
    {:reply, history.accounts[apid], history}
  end
end
