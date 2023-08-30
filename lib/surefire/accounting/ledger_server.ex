defmodule Surefire.Accounting.LedgerServer do
  defmodule Book do
    @moduledoc ~s"""
    TMP: general ledger with multiple accounts.

    WIP: Here the accounting period is the lifetime of the current process.
    On process end / closing, the assets are restituted to the parent process
    """

    alias Surefire.Accounting.{LogCache, Account, Transaction}

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
          %__MODULE__{last_reflected: last_reflected} = book,
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
            cond do
              entry.account in Map.keys(book.accounts) ->
                %{
                  book
                  | accounts:
                      book.accounts
                      |> Map.update!(entry.account, &Account.append(&1, entry))
                }

              true ->
                raise RuntimeError, message: "#{entry.account} doesnt exists!"
                # TODO : auto create the account or error ?
                # TODO : skip the transaction or not ? (should be relying on this ledger!)
            end
        end

      # TODO : handle keyerror
      %{updated_book | last_reflected: transaction_id}
    end

    def reflect(%__MODULE__{} = book, %LogCache{chunk: chunk}) do
      # CAREFUL : the history should be sorted (lexical order of ids)
      # to make sure we pass the transactions in order
      for {tid, t} <- chunk.transactions, reduce: book do
        book_acc -> reflect(book_acc, t, tid)
      end
    end
  end

  @moduledoc ~s"""
  A GenServer, holding a ledger and managing it.
  However, a Ledger is simply a read model over the Transactions Log, managed by the `LogServer`.
    We access them via `LogCache`, keeping track of what has been seen or not...

  Note: This is used both on the player process, as well as for the game process.
  """

  alias Surefire.Accounting.{LogCache, Account, Transaction}

  use GenServer
  # TODO : use GenStage instead ? most of the functionality already done ??

  # TODO : implement using, so the user (player, and game modules)
  #        can do `use LedgerServer, history: pid_atom`
  #        and code their own Server on it...

  # Client

  def start_link(history_pid, _opts \\ []) do
    # TODO : make sure the history is started...
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
    {:ok, {LogCache.new(history_pid), Book.new()}}
  end

  @impl true
  def handle_call({:open, aid, aname, :debit}, _from, {log_cache, book}) do
    updated_book = book |> Book.open_debit_account(aid, aname)

    {:reply, :ok, {log_cache, updated_book}}
  end

  @impl true
  def handle_call({:open, aid, aname, :credit}, _from, {log_cache, book}) do
    updated_book = book |> Book.open_credit_account(aid, aname)

    {:reply, :ok, {log_cache, updated_book}}
  end

  @impl true
  def handle_call({:balance, aid}, _from, {log_cache, book}) do
    recent_cache = log_cache |> LogCache.next()

    updated_book = book |> Book.reflect(recent_cache)
    # TODO : dropping cache ? we dont need it any longer...
    {:reply, updated_book.accounts[aid] |> Account.balance(), {recent_cache, updated_book}}
  end

  @impl true
  def handle_call({:view, aid}, _from, {log_cache, book}) do
    recent_cache = log_cache |> LogCache.next()

    updated_book = book |> Book.reflect(recent_cache)
    # TODO : dropping cache ? we dont need it any longer...
    {:reply, updated_book.accounts[aid], {recent_cache, updated_book}}
  end

  # TODO: close account
end
