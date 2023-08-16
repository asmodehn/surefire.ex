defmodule Surefire.Accounting.Ledger.Balance do
  alias Surefire.Accounting.Transaction

  defstruct debits: 0,
            credits: 0

  @type t :: %__MODULE__{
          debits: integer(),
          credits: integer()
        }

  def update(
        %__MODULE__{debits: debits, credits: credits} = balance,
        %Transaction.Entry{debit: debit, credit: credit}
      ) do
    %{balance | debits: debits + debit, credits: credits + credit}
  end
end

defmodule Surefire.Accounting.Ledger do
  @moduledoc ~s"""
  Ledger structure, suitable for display to a user.

  Note : Ledger are just a cache, ie. a read model on top of transaction history.

  """

  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.Ledger.Balance

  @derive {Inspect, only: [:balance, :closed]}
  defstruct entries: [],
            balance: %Balance{},
            closed: false

  @type t :: %__MODULE__{
          entries: [Transaction.Entry.t()],
          balance: Balance.t(),
          closed: boolean()
        }

  def new(debits_balance \\ 0, credits_balance \\ 0)
      when is_integer(debits_balance) and is_integer(credits_balance) do
    %__MODULE__{balance: %Balance{debits: debits_balance, credits: credits_balance}}
  end

  @doc ~s"""
  append/2 appends a transaction to the ledger, if its id exists (comes from the History).
  CAREFUL: at this level nothing guarantees the unicity of the entry in the ledger.
  see `Account` to make sure a transaction is only reflected once in the ledger.
  """
  def append(
        %__MODULE__{entries: entries, balance: balance} = ledger,
        %Transaction.Entry{} = entry
      )
      when entry.transaction_id != nil do
    %{ledger | entries: entries ++ [entry], balance: Balance.update(balance, entry)}
  end

  # TODO : inspect
  # TODO : string.chars

  # TODO: Collectable: to be used as a read model from transactions archive !??
end
