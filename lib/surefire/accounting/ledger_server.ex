defmodule Surefire.Accounting.LedgerServer do
  defmodule Book do
    @moduledoc ~s"""
    TMP: general ledger with multiple accounts.

    WIP: Here the accounting period is the lifetime of the current process.
    On process end / closing, the assets are restituted to the parent process
    """

    alias Surefire.Accounting.{History, Account, Transaction}

    defstruct accounts: %{},
              # TODO : stream to make this implicit...
              last_reflected: nil

    # TODO : => this should be only a map of accounts...

    @type t :: %__MODULE__{
            accounts: %{atom => Account.t()},
            last_reflected: atom
          }

    def new(creation_transaction \\ nil) do
      %__MODULE__{last_reflected: creation_transaction}
    end

    def open_debit_account(%__MODULE__{} = book, id, name) do
      %{book | accounts: book.accounts |> Map.put(id, Account.new_debit(id, name))}
    end

    def open_credit_account(%__MODULE__{} = book, id, name) do
      %{book | accounts: book.accounts |> Map.put(id, Account.new_credit(id, name))}
    end

    # TODO : review & test this
    def reflect(
          %__MODULE__{last_reflected: last_reflected},
          %Transaction{},
          transaction_id
        )
        when last_reflected > transaction_id do
      raise RuntimeError, message: "ERROR: old transaction id sent to ledger server !"
      # In this case => check tid sort order and sequence of transactions in calls to reflect/3
    end

    def reflect(
          %__MODULE__{last_reflected: last_reflected} = book,
          %Transaction{},
          transaction_id
        )
        when last_reflected == transaction_id do
      # already reflected  !
      book
    end

    def reflect(
          %__MODULE__{last_reflected: last_reflected} = book,
          %Transaction{} = transaction,
          transaction_id
        )
        when last_reflected < transaction_id do
      updated_book =
        for entry <- transaction |> Transaction.as_entries(transaction_id), reduce: book do
          book ->
            if entry.account in Map.keys(book.accounts) do
              %{
                book
                | accounts:
                    book.accounts
                    |> Map.update!(entry.account, &Account.append(&1, entry))
              }
            else
              raise RuntimeError, message: "#{entry.account} doesnt exists!"
              # TODO : skip the transaction if account doesnt exist.
              # Transaction with account matching should be enforced on commit (not on read !)
            end
        end

      %{updated_book | last_reflected: transaction_id}
    end

    def reflect(%__MODULE__{} = book, %History.Chunk{transactions: transactions}) do
      # CAREFUL : the history should be sorted (lexical order of ids)
      # to make sure we pass the transactions in order
      for {tid, t} <- transactions, reduce: book do
        book_acc -> reflect(book_acc, t, tid)
      end
    end
  end

  @moduledoc ~s"""
  A GenServer, holding a ledger and managing it.
  However, a Ledger is simply a read model over the Transactions Log, managed by the `LogServer`.

  Note: This is used both on the player process, as well as for the game process.
  """

  alias Surefire.Accounting.{LogServer, History, Account, Transaction}

  use GenServer

  # TODO : implement using, so the user (player, and game modules)
  #        can do `use LedgerServer, history: pid_atom`
  #        and code their own Server on it...

  # Client

  def start_link(history_pid, _opts \\ []) do
    if Process.alive?(history_pid) do
      GenServer.start_link(__MODULE__, history_pid)
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

  # Server (callbacks)

  @impl true
  def init(history_pid) do
    # TODO : maybe an optional starting date ?? or only in each accounts when opening ?
    {:ok, {history_pid, nil, Book.new()}}
  end

  @impl true
  def handle_call({:open, aid, aname, :debit}, _from, {hpid, chunk, book}) do
    updated_book = book |> Book.open_debit_account(aid, aname)
    # TODO : open account on log_server to accept transactions with it
    {:reply, :ok, {hpid, chunk, updated_book}}
  end

  @impl true
  def handle_call({:open, aid, aname, :credit}, _from, {hpid, chunk, book}) do
    updated_book = book |> Book.open_credit_account(aid, aname)
    # TODO : open account on log_server to accept transactions with it

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

  # TODO: close account

  defp new_chunk(hpid, nil) do
    LogServer.chunk(hpid, from: nil)
  end

  defp new_chunk(hpid, %History.Chunk{} = last_chunk) do
    LogServer.chunk(hpid, from: last_chunk.until)
  end
end
