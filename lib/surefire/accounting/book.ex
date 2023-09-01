defmodule Surefire.Accounting.LedgerServer.Book do
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

  def close_account(%__MODULE__{} = book, id) do
    %{book | accounts: book.accounts |> Map.delete(id)}
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
      for entry <- transaction |> Transaction.as_entries(transaction_id, self()),
          reduce: book do
        book ->
          if entry.account in Map.keys(book.accounts) do
            %{
              book
              | accounts:
                  book.accounts
                  |> Map.update!(entry.account, &Account.append(&1, entry))
            }
          else
            # skip the transaction if account doesnt exist.
            # Transaction with account matching should be enforced on commit, not on read !
            book
            # TODO : maybe an auto-creation option ??
            # Seems we may have two usecases:
            # - intentionally filterout accounts we do not care about,
            # - potentially see accounts we did not know about...
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
