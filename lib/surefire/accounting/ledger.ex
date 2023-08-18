defmodule Surefire.Accounting.Ledger.Balance do
  alias Surefire.Accounting.Transaction

  @derive Inspect
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
  A Ledger is a read model over the transactions history.
  However, a ledger can only belong to one account, as this account_id is used to filter entries added to it.

  """

  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.Ledger.Balance

  defstruct account: nil,
            entries: [],
            balance: %Balance{},
            closed: false

  @type t :: %__MODULE__{
          account: atom,
          entries: [Transaction.Entry.t()],
          balance: Balance.t(),
          closed: boolean()
        }

  def new(account_id, debits_balance \\ 0, credits_balance \\ 0)
      when is_atom(account_id) and is_integer(debits_balance) and is_integer(credits_balance) do
    %__MODULE__{
      account: account_id,
      balance: %Balance{debits: debits_balance, credits: credits_balance}
    }
  end

  @doc ~s"""
  append/2 appends an entry to the ledger, if its id exists (comes from the History).
  CAREFUL: at this level nothing guarantees:
  - the ledger account match  the entry account. see 'filter_append/3` for this.
  - the unicity of the transaction in the ledger. see `Account` for this.
  """
  def append(
        %__MODULE__{account: ledger_account_id, entries: entries, balance: balance} = ledger,
        %Transaction.Entry{account: entry_account_id} = entry
      )
      when entry.transaction_id != nil and entry_account_id == ledger_account_id do
    %{ledger | entries: entries ++ [entry], balance: Balance.update(balance, entry)}
  end

  @doc ~s"""
  filter_append appends an entry to the ledger, only if its account matches the parameter.
  """
  def reflect(%__MODULE__{account: account_id} = ledger, entry_list)
      when is_list(entry_list) do
    entry_list
    |> Enum.reduce(ledger, fn
      %Transaction.Entry{} = e, l when e.account == account_id -> append(l, e)
      _, l -> l
    end)
  end

  defimpl String.Chars do
    def to_string(%Surefire.Accounting.Ledger{} = ledger) do
      TableRex.quick_render!(
        ledger.entries |> Enum.map(fn e -> Map.values(e) |> Enum.drop(1) end),
        %Transaction.Entry{} |> Map.keys() |> Enum.drop(1)
      )
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(ledger, opts) do
      concat([
        "#Surefire.Accounting.Ledger<",
        Inspect.Atom.inspect(ledger.account, opts),
        Inspect.Algebra.break("\n"),
        "[#{length(ledger.entries)} entries]",
        Inspect.Algebra.break("\n"),
        Inspect.Surefire.Accounting.Ledger.Balance.inspect(ledger.balance, opts),
        Inspect.Algebra.break("\n"),
        if ledger.closed do
          "CLOSED!"
        else
          "ONGOING..."
        end,
        ">"
      ])
    end
  end

  # TODO leverage this in display with Table_rex.
  # See: https://github.com/djm/table_rex/issues/56
  defimpl Table.Reader do
    def init(ledger) do
      Table.Reader.Enumerable.init_rows(ledger.entries)
    end
  end
end
