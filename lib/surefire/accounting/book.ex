defmodule Surefire.Accounting.Book do
  @moduledoc ~s"""
  TMP: general ledger with multiple accounts.

  WIP: Here the accounting period is the lifetime of the current process.
  On process end / closing, the assets are restituted to the parent process
  """

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.History
  alias Surefire.Accounting.Transaction

  defstruct accounts: %{},
            last_reflected: nil

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
      when last_reflected >= transaction_id do
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
            # TODO : keep this and get rid of distinction between internal and externals...
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

  def reflect(%__MODULE__{} = book, %History{} = history) do
    # CAREFUL : the history should be sorted (lexical order of ids)
    # to make sure we pass the transactions in order
    for {tid, t} <- history.transactions, reduce: book do
      book_acc -> reflect(book_acc, t, tid)
    end
  end
end
