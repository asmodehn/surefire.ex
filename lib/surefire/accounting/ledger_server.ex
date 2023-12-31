defmodule Surefire.Accounting.LedgerServer do
  @moduledoc ~s"""
  A GenServer, holding a ledger and managing it.
  However, a Ledger is simply a read model over the Transactions Log, managed by the `LogServer`.

  Note: This is used both on the player process, as well as for the game process.
  """

  alias Surefire.Accounting.{LogServer, History, Account, Transaction}
  alias Surefire.Accounting.LedgerServer.Book
  alias Surefire.Accounting.AccountID

  use GenServer

  # Client

  def start_link(history_pid \\ [], opts \\ [])

  def start_link([], opts) do
    start_link(Process.whereis(LogServer), opts)
  end

  # TODO : make history an option, and pass Book as init_arg ??
  def start_link(history_pid, opts) when is_pid(history_pid) do
    if Process.alive?(history_pid) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, history_pid, name: name)
    else
      raise RuntimeError, message: "ERROR: #{history_pid} is not started !"
    end
  end

  def open_account(pid, id, name, :debit) do
    GenServer.call(pid, {:open, id, name, :debit})
  end

  def open_account(pid, id, name, :credit) do
    GenServer.call(pid, {:open, id, name, :credit})
  end

  def balance(pid, account_id) do
    GenServer.call(pid, {:balance, account_id})
  end

  def view(pid, account_id) do
    GenServer.call(pid, {:view, account_id})
  end

  def close_account(pid, id) do
    GenServer.call(pid, {:close, id})
  end

  # depending on possible **internal** operations for this ledger...
  def transfer_debit(pid, descr, from_account, to_account, amount) do
    transaction =
      Transaction.build(descr)
      |> Transaction.with_credit(pid, from_account, amount)
      |> Transaction.with_debit(pid, to_account, amount)

    # Note: transactions are safe to transfer around: atomic event-like / message-like
    tid = GenServer.call(pid, {:transfer, transaction})

    tid
  end

  def transfer_credit(pid, descr, from_account, to_account, amount) do
    transaction =
      Transaction.build(descr)
      |> Transaction.with_debit(pid, from_account, amount)
      |> Transaction.with_credit(pid, to_account, amount)

    # Note: transactions are safe to transfer around: atomic event-like / message-like
    tid = GenServer.call(pid, {:transfer, transaction})

    tid
  end

  # TODO : rename to "record" maybe ?
  def transfer(pid, %Transaction{} = transaction) do
    # Note: transactions are safe to transfer around: atomic event-like / message-like
    tid = GenServer.call(pid, {:transfer, transaction})

    tid
  end

  # Server (callbacks)

  @impl true
  def init(history_pid) do
    # TODO : maybe an optional starting date ?? or only in each accounts when opening ?
    {:ok, {history_pid, nil, Book.new()}}
  end

  @impl true
  def handle_call({:open, aid, aname, :debit}, _from, {hpid, chunk, book}) do
    updated_book = book |> Book.open_debit_account(aid, aname)

    :ok = LogServer.open_account(hpid, self(), aid)

    {:reply, :ok, {hpid, chunk, updated_book}}
  end

  @impl true
  def handle_call({:open, aid, aname, :credit}, _from, {hpid, chunk, book}) do
    updated_book = book |> Book.open_credit_account(aid, aname)

    :ok = LogServer.open_account(hpid, self(), aid)

    {:reply, :ok, {hpid, chunk, updated_book}}
  end

  @impl true
  def handle_call({:balance, aid}, _from, {hpid, last_chunk, book}) do
    # grab new history chunk and reflect in book
    chunk = new_chunk(hpid, last_chunk)
    updated_book = book |> Book.reflect(chunk)
    # dropping cache ? we dont need it any longer...
    {:reply, updated_book.accounts[aid] |> Account.balance(), {hpid, chunk, updated_book}}
  end

  @impl true
  def handle_call({:view, aid}, _from, {hpid, last_chunk, book}) do
    # grab new history chunk and reflect in book
    chunk = new_chunk(hpid, last_chunk)
    updated_book = book |> Book.reflect(chunk)
    # dropping cache ? we dont need it any longer...
    {:reply, updated_book.accounts[aid], {hpid, chunk, updated_book}}
  end

  @impl true
  def handle_call({:close, aid}, _from, {hpid, chunk, book}) do
    updated_book = book |> Book.close_account(aid)

    :ok = LogServer.close_account(hpid, self(), aid)

    {:reply, :ok, {hpid, chunk, updated_book}}
  end

  @impl true
  def handle_call({:transfer, %Transaction{} = transaction}, _from, {hpid, chunk, book}) do
    tid = LogServer.commit(hpid, transaction)
    {:reply, tid, {hpid, chunk, book}}
  end

  defp new_chunk(hpid, nil) do
    LogServer.chunk(hpid, from: nil)
  end

  defp new_chunk(hpid, %History.Chunk{} = last_chunk) do
    LogServer.chunk(hpid, from: last_chunk.until)
  end
end
