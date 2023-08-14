defmodule Surefire.Accounting.History do
  @moduledoc ~s"""
  Manages the transaction history
    Consequences:
   - consistency is priviledged over current balance
    - transactions are stored (just like an event), not individual entries.
   - always in sync with presented data via the ledger (read model).
  """

  alias Surefire.Accounting.Transaction

  defstruct transactions: %{}

  @type t :: %__MODULE__{
          transactions: %{String.t() => Transaction.t()}
        }

  @spec new_transaction_id() :: String.t()
  def new_transaction_id() do
    :ulid.generate()
    # TODO : might not be monotonic (but very likely unique...)
    # => BUG hiding in there...
  end

  @spec commit(t(), String.t(), Transaction.t()) :: {:ok, t()} | {:error, any()}

  def commit(%__MODULE__{transactions: transactions}, id, _)
      when is_map_key(transactions, id) do
    {:error, :existing_transaction_id}
  end

  def commit(%__MODULE__{} = history, id, %Transaction{date: nil} = transact) do
    commit(history, transact |> Transaction.with_current_date(), id)
  end

  def commit(%__MODULE__{} = history, id, %Transaction{date: _date} = transact) do
    with {:balanced, true} <- {:balanced, Transaction.verify_balanced(transact)} do
      {:ok, %{history | transactions: history.transactions |> Map.put_new(id, transact)}}
    else
      {:balanced, false} -> {:error, :unbalanced_transaction}
    end
  end
end
