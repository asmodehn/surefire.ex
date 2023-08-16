defmodule Surefire.Accounting.History do
  @moduledoc ~s"""
  Manages the transaction history
    Consequences:
   - consistency is priviledged over current balance
    - transactions are stored (just like an event), not individual entries.
   - always in sync with presented data via the ledger (read model).
  """

  alias Surefire.Accounting.Transaction

  defstruct id_generator: nil,
            transactions: %{}

  @type t :: %__MODULE__{
          id_generator: any,
          transactions: %{String.t() => Transaction.t()}
        }

  def new() do
    %{%__MODULE__{} | id_generator: :ulid.new()}
  end

  @spec new_transaction_id(t()) :: {String.t(), t()}
  def new_transaction_id(%__MODULE__{id_generator: id_gen} = history) do
    {next_gen, ulid} = :ulid.generate(id_gen)
    {ulid, %{history | id_generator: next_gen}}
    # CAREFUL: might not be monotonic because system_time might not be (but very likely unique...)
    # => BUG hiding in there...
    # TODO: replace system_time by monotonous_time
    # => Pb: this makes it dependent on the node where it is generated -> not cross-node comparable
    # => Build an process interface around, maybe similar to https://github.com/jur0/eid
    #   OR modify/extend the content of the id as in https://github.com/fogfish/uid or https://github.com/okeuday/uuid
  end

  @spec commit(t(), String.t(), Transaction.t()) :: {:ok, t()} | {:error, any()}

  def commit(%__MODULE__{transactions: transactions}, id, _)
      when is_map_key(transactions, id) do
    {:error, :existing_transaction_id}
  end

  def commit(%__MODULE__{} = history, id, %Transaction{date: nil} = transact) do
    commit(history, id, transact |> Transaction.with_current_date())
  end

  def commit(%__MODULE__{} = history, id, %Transaction{date: _date} = transact) do
    with {:balanced, true} <- {:balanced, Transaction.verify_balanced(transact)} do
      {:ok, %{history | transactions: history.transactions |> Map.put_new(id, transact)}}
    else
      {:balanced, false} -> {:error, :unbalanced_transaction}
    end
  end
end
