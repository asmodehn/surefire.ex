defmodule Surefire.Accounting.Transaction do
  defmodule Entry do
    @moduledoc ~s"""
    An "account entry", however it is not what is recorded.
    Insead an Entry is a read model / a view of a part of a transaction.
    It is the building block of an `Account`.
    """

    @derive {Inspect, only: [:date, :description, :debit, :credit]}
    defstruct transaction_id: nil,
              account: nil,
              date: nil,
              description: "",
              debit: 0,
              credit: 0

    @type t :: %__MODULE__{
            transaction_id: String.t(),
            account: atom,
            date: DateTime.t(),
            description: String.t(),
            # TODO : should always be positive ?
            #  -> negative only special case for corrections ?
            debit: integer,
            credit: integer
          }

    # TODO : String.Char for nice display ?
  end

  @moduledoc ~s"""
  Transaction is an event that is recorded and cannot be modified afterwards.
  It is possible to build a transaction in multiple steps, but once it is committed it should not be used any longer.

  Note: Even if the transaction is a actual unique atomic "event", for optimisation on local read models,
  the transaction is split into various entries, stored in multiple accounts in the ledger.
  This is an optimisation as we are mostly interested in the "balance of an account", and we want to optimise for this case.
  As accounting is local to a process, we don't lose anything in doing so, except performance if transaction browsing ever becomes the main usage..
  """

  defstruct date: nil,
            description: "",
            debit: [],
            credit: []

  @type t :: %__MODULE__{
          date: DateTime.t(),
          description: String.t(),
          debit: Keyword.t(),
          credit: Keyword.t()
        }

  def build(description) do
    %__MODULE__{description: description}
  end

  def with_debit(%__MODULE__{debit: debits} = transact, account_id, amount)
      when is_nil(transact.date) and is_atom(account_id) and is_integer(amount) do
    %{transact | debit: debits ++ [{account_id, amount}]}
  end

  def with_debits(%__MODULE__{} = transact, acc_amounts \\ []) do
    acc_amounts
    |> Enum.reduce(transact, fn
      {acc, amnt}, t -> t |> with_debit(acc, amnt)
    end)
  end

  def with_credit(%__MODULE__{credit: credits} = transact, account_id, amount)
      when is_nil(transact.date) and is_atom(account_id) and is_integer(amount) do
    %{transact | credit: credits ++ [{account_id, amount}]}
  end

  def with_credits(%__MODULE__{} = transact, acc_amounts \\ []) do
    acc_amounts
    |> Enum.reduce(transact, fn
      {acc, amnt}, t -> t |> with_credit(acc, amnt)
    end)
  end

  def with_current_date(%__MODULE__{} = transact, date_func \\ &DateTime.utc_now/0) do
    %{transact | date: date_func.()}
  end

  @spec verify_balanced(t()) :: boolean
  def verify_balanced(%__MODULE__{debit: debits, credit: credits}) do
    debits |> Enum.map(&elem(&1, 1)) |> Enum.sum() ==
      credits |> Enum.map(&elem(&1, 1)) |> Enum.sum()
  end

  @spec as_entries(t(), String.t()) :: [Entry.t()]
  def as_entries(
        %__MODULE__{
          date: date,
          description: description,
          debit: debits,
          credit: credits
        },
        transaction_id
      ) do
    for {account, amount} <- debits do
      %Entry{
        transaction_id: transaction_id,
        account: account,
        date: date,
        description: description,
        debit: amount
      }
    end ++
      for {account, amount} <- credits do
        %Entry{
          transaction_id: transaction_id,
          account: account,
          date: date,
          description: description,
          credit: amount
        }
      end
  end
end
