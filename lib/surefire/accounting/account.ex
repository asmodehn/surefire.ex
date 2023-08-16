defmodule Surefire.Accounting.Account do
  @moduledoc ~s"""
  Account is a data structure identifying origin or destination of a transaction.
  It sid is used to filter relevant transaction to take in account in its ledger.
  """

  alias Surefire.Accounting.Ledger
  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.History

  @derive {Inspect, only: [:name, :ledger]}
  defstruct id: nil,
            name: "",
            type: :debit,
            ledger: %Ledger{},
            last_seen_transaction: nil

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          type: :debit | :credit,
          ledger: Ledger.t(),
          last_seen_transaction: nil | String.t()
        }

  def new_debit(id, name, opening \\ 0) when is_integer(opening) when is_atom(id) do
    %__MODULE__{
      id: id,
      name: name,
      type: :debit,
      ledger:
        cond do
          opening >= 0 -> Ledger.new(opening, 0)
          opening < 0 -> Ledger.new(0, -opening)
        end
    }
  end

  def new_credit(id, name, opening \\ 0) when is_integer(opening) when is_atom(id) do
    %__MODULE__{
      id: id,
      name: name,
      type: :credit,
      ledger:
        cond do
          opening >= 0 -> Ledger.new(0, opening)
          opening < 0 -> Ledger.new(-opening, 0)
        end
    }
  end

  def balance(%__MODULE__{type: :debit, ledger: %Ledger{balance: balance}}) do
    balance.debits - balance.credits
  end

  def balance(%__MODULE__{type: :credit, ledger: %Ledger{balance: balance}}) do
    balance.credits - balance.debits
  end

  @doc ~s"""
  reflect/3 modifies the account to add entries for a transaction.
  However, to avoid processing N times the same transactions, this transaction must be
  more recent (relies on lexical order of transaction_id) than the previous one.
  => reflect must therefore be called onto the transaction in order of their ids.
  Otherwise, the transaction is simply ignored.
  """
  def reflect(
        %__MODULE__{id: account_id, last_seen_transaction: last_transact} = account,
        %Transaction{} = transaction,
        transaction_id
      )
      when last_transact < transaction_id do
    updated_ledger =
      transaction
      |> Transaction.as_entries(transaction_id)
      # TODO : filter transaction already added -> how ??
      |> Enum.filter(fn e -> e.account == account_id end)
      |> Enum.reduce(account.ledger, fn e, l -> Ledger.append(l, e) end)

    # TODO : use the ledger collectable interface to put transaction "into" it...

    %{account | ledger: updated_ledger, last_seen_transaction: transaction_id}
  end

  def reflect(
        %__MODULE__{id: account_id, last_seen_transaction: last_transact} = account,
        %Transaction{} = transaction,
        transaction_id
      ) do
    account
  end

  #  TODO:  Collectable to get Transactions from history ??
end
