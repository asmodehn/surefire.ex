defmodule Surefire.Accounting.Book do
  @moduledoc ~s"""
  TMP: general ledger with multiple accounts.

  WIP: Here the accounting period is the lifetime of the current process.
  On process end / closing, the assets are restituted to the parent process
  """

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.History
  alias Surefire.Accounting.Transaction

  defstruct assets: nil,
            liabilities: nil,
            revenue: nil,
            expenses: nil,
            externals: %{},
            last_reflected: nil

  @type t :: %__MODULE__{
          assets: Account.t(),
          liabilities: Account.t(),
          revenue: Account.t(),
          expenses: Account.t(),
          externals: %{atom => Account.t()},
          last_reflected: atom
        }

  # TODO MAYBE ? def new(starting_assets, starting_liabilities // 0) do
  def new(initial_assets \\ 0, liabilities \\ 0) do
    %__MODULE__{
      assets: Account.new_debit(:assets, "Assets", initial_assets),
      liabilities: Account.new_credit(:liabilities, "Liabilities", liabilities),
      revenue: Account.new_debit(:revenue, "Revenue"),
      expenses: Account.new_credit(:expenses, "Expenses")
    }
  end

  def add_external(%__MODULE__{} = book, %Account{} = account) do
    %{book | externals: book.externals |> Map.put(account.id, account)}
  end

  # TODO : review & test this
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
            entry.account in [:assets, :liabilities, :revenue, :expenses] ->
              book |> Map.update!(entry.account, &Account.append(&1, entry))

            entry.account in Map.keys(book.externals) ->
              %{
                book
                | externals:
                    book.externals
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
    for {tid, t} <- history.transaction, reduce: book do
      book_acc -> reflect(book_acc, t, tid)
    end
  end
end
