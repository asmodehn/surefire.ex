defmodule Surefire.BizServer do
  @moduledoc ~s"""
  A GenServer, holding a ledger and managing it.

    Note: Thi sis used both on the player process, as well as for the game process.

  """

  alias Surefire.Accounting
  alias Surefire.Accounting.Book

  use GenServer
  # TODO : change into LedgerServer, so the user can do `use LedgerServer, history: pid_atom`
  # and code his own Server on it... (Player or Game)

  # Client

  def start_link(history_pid, _opts \\ []) do
    GenServer.start_link(__MODULE__, history_pid)
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

  # Server (callbacks)

  @impl true
  def init(history_pid) do
    book = Surefire.Accounting.Book.new()
    {:ok, {history_pid, book}}
  end

  @impl true
  def handle_call({:open, aid, aname, :debit}, _from, {h, book}) do
    updated_book = book |> Book.open_debit_account(aid, aname)

    {:reply, :ok, {h, updated_book}}
  end

  @impl true
  def handle_call({:open, aid, aname, :credit}, _from, {h, book}) do
    updated_book = book |> Book.open_credit_account(aid, aname)

    {:reply, :ok, {h, updated_book}}
  end

  @impl true
  def handle_call({:balance, aid}, _from, {h, book}) do
    updated_book = book |> Book.reflect(h |> Accounting.transactions(since: book.last_reflected))
    {:reply, updated_book.accounts[aid] |> Accounting.Account.balance(), {h, updated_book}}
  end

  @impl true
  def handle_call({:view, aid}, _from, {h, book}) do
    updated_book = book |> Book.reflect(h |> Accounting.transactions(since: book.last_reflected))
    {:reply, updated_book.accounts[aid], {h, updated_book}}
  end
end
