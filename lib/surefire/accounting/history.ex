defmodule Surefire.Accounting.History.Chunk do
  @moduledoc ~s"""
  Data of a chunk of transaction history
  """

  alias Surefire.Accounting.LogServer

  defstruct from: nil,
            until: nil,
            transactions: %{}

  @type t :: %__MODULE__{
          from: String.t(),
          until: String.t(),
          transactions: %{String.t() => Transaction.t()}
        }

  def build(no_transactions) when no_transactions == %{} do
    %__MODULE__{}
  end

  def build(transactions) do
    tids = transactions |> Map.keys()

    %__MODULE__{
      from: Enum.min(tids),
      until: Enum.max(tids),
      transactions: transactions
    }
  end
end

defmodule Surefire.Accounting.History do
  @moduledoc ~s"""
  Manages the transaction history
    Consequences:
   - consistency is priviledged over current balance
    - transactions are stored (just like an event), not individual entries.
   - always in sync with presented data via the ledger (read model).
  """

  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.History.Chunk

  defstruct id_generator: nil,
            transactions: %{},
            last_committed_id: nil

  @type t :: %__MODULE__{
          id_generator: any,
          # TODO : redesign this to be a `LogChunk` although the biggest/original one...
          transactions: %{String.t() => Transaction.t()},
          last_committed_id: nil | String.t()
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

  def new_transaction_id(%__MODULE__{id_generator: nil} = history) do
    # in this case we want to prevent  generating(we doonot know where this copy comes from ??)
    # probably generated from transactions_from/n ??
    raise RuntimeError, message: "Attempt to create id from History Clone"
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
      {:ok,
       %{
         history
         | transactions: history.transactions |> Map.put_new(id, transact),
           last_committed_id: id
       }}
    else
      {:balanced, false} -> {:error, :unbalanced_transaction}
    end
  end

  def chunk(%__MODULE__{transactions: transactions}) do
    Chunk.build(transactions)
  end

  def chunk(%__MODULE__{transactions: transactions} = history, opts) when is_list(opts) do
    case {Keyword.get(opts, :from), Keyword.get(opts, :until)} do
      {from, nil} ->
        Chunk.build(transactions |> Map.filter(fn {k, _} -> k >= from end))

      {nil, until} ->
        Chunk.build(transactions |> Map.filter(fn {k, _} -> k <= until end))

      {from, until} ->
        Chunk.build(transactions |> Map.filter(fn {k, _} -> k >= from and k <= until end))
    end
  end
end
