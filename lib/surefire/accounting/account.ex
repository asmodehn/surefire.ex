defmodule Surefire.Accounting.Account do
  @moduledoc ~s"""
  Account is a data structure identifying origin or destination of a transaction.
  It sid is used to filter relevant transaction to take in account in its ledger.
  """

  alias Surefire.Accounting.Ledger
  alias Surefire.Accounting.Transaction

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
          opening >= 0 -> Ledger.new(id, opening, 0)
          opening < 0 -> Ledger.new(id, 0, -opening)
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
          opening >= 0 -> Ledger.new(id, 0, opening)
          opening < 0 -> Ledger.new(id, -opening, 0)
        end
    }
  end

  # TODO :is debit/credit type only important for balance ? or really useful as part of data ??
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
        %__MODULE__{last_seen_transaction: last_transact, ledger: ledger} = account,
        %Transaction{} = transaction,
        transaction_id
      )
      # TODO should be checking entry account_id as well here !
      when last_transact < transaction_id do
    updated_ledger =
      ledger |> Ledger.reflect(transaction |> Transaction.as_entries(transaction_id))

    %{account | ledger: updated_ledger, last_seen_transaction: transaction_id}
  end

  # TODO : should be included in caller on transaction history instead of here (just like reflect in ledger).
  def reflect(
        %__MODULE__{} = account,
        %Transaction{},
        _transaction_id
      ) do
    account
  end
end
