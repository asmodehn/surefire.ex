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

  def with_credit(%__MODULE__{credit: credits} = transact, account_id, amount)
      when is_nil(transact.date) and is_atom(account_id) and is_integer(amount) do
    %{transact | credit: credits ++ [{account_id, amount}]}
  end

  # API attempt( from the point of view of player -> avatars
  def funding_to(
        amount,
        %Account{name: acc_name, type: :debit} = avatar_asset_account,
        ledger_asset_account_id \\ :assets
      ) do
    build("Funding to #{acc_name}")
    |> with_credit(ledger_asset_account_id, amount)
    |> with_debit(avatar_asset_account.id, amount)
  end

  def repayment_from(
        amount,
        %Account{name: acc_name, type: :debit} = avatar_asset_account,
        ledger_asset_account_id \\ :assets
      ) do
    build("Repayment from #{acc_name}")
    |> with_debit(ledger_asset_account_id, amount)
    |> with_credit(avatar_asset_account.id, amount)
  end

  def earning_at(
        amount,
        %Account{name: acc_name, type: :debit} = avatar_asset_account,
        ledger_revenue_account_id \\ :revenue
      ) do
    build("#{acc_name} Earning record")
    |> with_credit(ledger_revenue_account_id, amount)
    |> with_debit(avatar_asset_account.id, amount)
  end

  def collect_from(
        amount,
        %Account{name: acc_name, type: :debit} = avatar_asset_account,
        ledger_revenue_account_id \\ :revenue
      ) do
    build("#{acc_name} Earning collection")
    |> with_debit(ledger_revenue_account_id, 12)
    |> with_credit(avatar_asset_account.id, 12)
  end

  # API attempt from the point of view of the game
  # collect_from/2 is the same except with a different process
  # (game is another process with a ledger, but doesnt delegate to the round)
  # TODO...

  # TODO : multi level transactions :
  # - just add more entries(based on accounts)
  # - transaction still balanced, at multiple levels...
  # - transaction itself can be multilevel (if account_ids can be multilevels ?)...

  @doc ~s"""
  Adds the current date to the transaction. This effectively locks the transaction,
  and prevents adding more debits or credits.
  """
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
