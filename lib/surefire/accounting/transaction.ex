defmodule Surefire.Accounting.Transaction do
  defmodule Entry do
    @moduledoc ~s"""
    An "account entry", however it is not what is recorded.
    Insead an Entry is a read model / a view of a part of a transaction.
    It is the building block of an `Account`.
    """

    @derive {Inspect, except: [:account]}
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
  end

  @moduledoc ~s"""
  Transaction is an event that is recorded and cannot be modified afterwards.
  It is possible to build a transaction in multiple steps, but once it is committed it should not be used any longer.

  Note: Even if the transaction is a actual unique atomic "event", for optimisation on local read models,
  the transaction is split into various entries, stored in multiple accounts in the ledger.
  This is an optimisation as we are mostly interested in the "balance of an account", and we want to optimise for this case.
  As accounting is local to a process, we don't lose anything in doing so, except performance if transaction browsing ever becomes the main usage..
  """

  alias Surefire.Accounting.Account

  defstruct date: nil,
            description: "",
            debit: %{},
            credit: %{}

  @type t :: %__MODULE__{
          date: DateTime.t(),
          description: String.t(),
          debit: %{pid => Keyword.t()},
          credit: %{pid => Keyword.t()}
        }

  def build(description) do
    %__MODULE__{description: description}
  end

  def with_debit(%__MODULE__{debit: debits} = transact, ledger_pid, account_id, amount)
      when is_nil(transact.date) and is_pid(ledger_pid) and is_atom(account_id) do
    %{
      transact
      | debit:
          debits
          |> Map.update(
            ledger_pid,
            [{account_id, amount}],
            fn {p, d} -> d ++ [{account_id, amount}] end
          )
    }
  end

  def with_credit(%__MODULE__{credit: credits} = transact, ledger_pid, account_id, amount)
      when is_nil(transact.date) and is_pid(ledger_pid) and is_atom(account_id) do
    %{
      transact
      | credit:
          credits
          |> Map.update(
            ledger_pid,
            [{account_id, amount}],
            fn {p, d} -> d ++ [{account_id, amount}] end
          )
    }
  end

  # convenience functions only...
  def debit_transfer(from_pid, from_account, to_pid, to_account, amount) do
    build("Transfer #{amount} from #{from_pid} #{from_account} to #{to_pid} #{to_account}")
    |> with_debit(from_pid, from_account, amount)
    |> with_credit(to_pid, to_account, amount)
  end

  #   TODO : maybe to+pid to_account can be an option -> allow multiple ??
  def credit_transfer(from_pid, from_account, to_pid, to_account, amount) do
    build("Transfer #{amount} from #{from_pid} #{from_account} to #{to_pid} #{to_account}")
    |> with_credit(from_pid, from_account, amount)
    |> with_debit(to_pid, to_account, amount)
  end

  # API attempt from the point of view of the game
  # collect_from/2 is the same except with a different process
  # (game is another process with a ledger, but doesnt delegate to the round)
  # TODO...

  @doc ~s"""
  Adds the current date to the transaction. This effectively locks the transaction,
  and prevents adding more debits or credits.
  """
  def with_current_date(%__MODULE__{} = transact, date_func \\ &DateTime.utc_now/0) do
    %{transact | date: date_func.()}
  end

  @spec verify_balanced(t()) :: boolean
  def verify_balanced(%__MODULE__{debit: debits, credit: credits}) do
    # Here we dont care about the pid, or the account id.
    # We only want that debit and credit values in the keyword lists are balanced
    debits |> Map.values() |> List.flatten() |> Enum.map(&elem(&1, 1)) |> Enum.sum() ==
      credits |> Map.values() |> List.flatten() |> Enum.map(&elem(&1, 1)) |> Enum.sum()
  end

  @spec as_entries(t(), String.t(), pid) :: [Entry.t()]
  def as_entries(
        %__MODULE__{
          date: date,
          description: description,
          debit: debits,
          credit: credits
        },
        transaction_id,
        ledger_pid
      ) do
    for {account, amount} <- Map.get(debits, ledger_pid, []) do
      %Entry{
        transaction_id: transaction_id,
        account: account,
        date: date,
        description: description,
        debit: amount
      }
    end ++
      for {account, amount} <- Map.get(credits, ledger_pid, []) do
        %Entry{
          transaction_id: transaction_id,
          account: account,
          date: date,
          description: description,
          credit: amount
        }
      end
  end

  def debited_accounts(%__MODULE__{
        date: date,
        description: description,
        debit: debits,
        credit: credits
      }) do
    debits
    |> Enum.map(fn {p, ak} -> {p, Keyword.keys(ak)} end)
    |> Enum.into(%{})
  end

  def credited_accounts(%__MODULE__{
        date: date,
        description: description,
        debit: debits,
        credit: credits
      }) do
    credits
    |> Enum.map(fn {p, ak} -> {p, Keyword.keys(ak)} end)
    |> Enum.into(%{})
  end
end
