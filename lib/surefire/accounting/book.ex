defmodule Surefire.Accounting.Book do
  @moduledoc ~s"""
  TMP: general ledger with multiple accounts.

  WIP: Here the accounting period is the lifetime of the current process.
  On process end / closing, the assets are restituted to the parent process
  """

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.History
  alias Surefire.Accounting.Transaction


  defstruct chart: %{},
            last_reflected: nil


  @type t :: %__MODULE__{
               chart: %{atom => Account.t()},
                last_reflected: atom
             }

# TODO MAYBE ? def new(starting_assets, starting_liabilities // 0) do
  def new() do
    %__MODULE__{}
  end

# TODO : ledger must have various accounts already
# debit normal + credit normal (minimum)
# Asset & Libability ++ Revenue & Expenses
# usual + contra...


  def add_account(%__MODULE__{} = book, %Account{}  = account) do
    %{book | chart: book.chart |> Map.put(account.id, account) }
  end

  # TODO : review & test this
  def reflect(%__MODULE__{last_reflected: last_reflected} = book,
        %Transaction{} = transaction,
        transaction_id
      )
      when last_reflected < transaction_id do

      updated_chart =  for entry <- transaction |> Transaction.as_entries(transaction_id), reduce: book.chart do
          chart -> chart
                   |> Map.update!(entry.account,
                fn existing_account -> Account.append(existing_account, entry) end
                    )
        end

        # TODO : handle keyerror
        %{book | chart: updated_chart, last_reflected: transaction_id}
  end

  def reflect(%__MODULE__{} = book, %History{} = history) do
    # CAREFUL : the history should be sorted (lexical order of ids)
    # to make sure we pass the transactions in order
    for {tid, t} <- history.transaction, reduce: book do
      book_acc -> reflect(book_acc, t, tid)
    end
  end



end