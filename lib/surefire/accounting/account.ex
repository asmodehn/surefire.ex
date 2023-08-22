defmodule Surefire.Accounting.Account.Balance do
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

defmodule Surefire.Accounting.Account do
  @moduledoc ~s"""
  Account is a data structure identifying origin or destination of a transaction.
  It sid is used to filter relevant transaction to take in account in its ledger.
  """

  alias Surefire.Accounting.Ledger
  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.Account.Balance

  @derive {Inspect, only: [:name, :balance]}
  defstruct id: nil,
            name: "",
            type: :debit,
            entries: [],
            balance: %Balance{},
  # TOOD : maybe we dont need this ??
            last_seen_transaction: nil

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          type: :debit | :credit,
          entries: [Transaction.Entry.t()],
          balance: Balance.t(),
          last_seen_transaction: nil | String.t()
        }

  def new_debit(id, name, opening \\ 0) when is_integer(opening) when is_atom(id) do
    %__MODULE__{
      id: id,
      name: name,
      type: :debit,
      balance:
        cond do
          opening >= 0 -> %Balance{debits: opening}
          opening < 0 -> %Balance{credits: -opening}
        end
    }
  end

  def new_credit(id, name, opening \\ 0) when is_integer(opening) when is_atom(id) do
    %__MODULE__{
      id: id,
      name: name,
      type: :credit,
      balance:
        cond do
          opening >= 0 -> %Balance{credits: opening}
          opening < 0 -> %Balance{debits: -opening}
        end
    }
  end

  # TODO : better interface :
  # - Asset (closing -> return to parent) & Expenses (closing -> stop paying it) (debit)
  # - Liability (closing -> - return to parent) & Revenue (closing -> stop getting it) (credit)
  # Pb : here or at higher lever of abstraction (with player / avatar) ??



  # TODO :is debit/credit type only important for balance ? or really useful as part of data ??
  def balance(%__MODULE__{type: :debit, balance: balance}) do
    balance.debits - balance.credits
  end

  def balance(%__MODULE__{type: :credit, balance: balance}) do
    balance.credits - balance.debits
  end
  @doc ~s"""
  append/2 appends an entry to the ledger, if its id exists (comes from the History).
  CAREFUL: at this level nothing guarantees:
  - the ledger account match  the entry account. see 'filter_append/3` for this.
  - the unicity of the transaction in the ledger. see `Account` for this.
  """
  def append(
        %__MODULE__{id: account_id, entries: entries, balance: balance} = account,
        %Transaction.Entry{account: entry_account_id} = entry
      )
      when entry.transaction_id != nil and entry_account_id == account_id do
    %{account | entries: entries ++ [entry], balance: Balance.update(balance, entry)}
  end


  # TODO : review this and put some (all?) of it in Book (expected caller)
  @doc ~s"""
  reflect/3 modifies the account to add entries for a transaction.
  However, to avoid processing N times the same transactions, this transaction must be
  more recent (relies on lexical order of transaction_id) than the previous one.
  => reflect must therefore be called onto the transaction in order of their ids.
  Otherwise, the transaction is simply ignored.
  """
  def reflect(
        %__MODULE__{last_seen_transaction: last_transact} = account,
        %Transaction{} = transaction,
        transaction_id
      )
      when last_transact < transaction_id do

    updated_account =
      for e <- ( transaction
                 |> Transaction.as_entries(transaction_id)
                 |> Enum.filter(fn e ->  e.account == account.id end)
        ), reduce: account do
          acc ->  acc |> append(e)
      end

    %{updated_account | last_seen_transaction: transaction_id}
  end

  defimpl String.Chars do
    def to_string(%Surefire.Accounting.Account{} = account) do
      TableRex.quick_render!(
        account.entries |> Enum.map(fn e -> Map.values(e) |> Enum.drop(1) end),
        %Transaction.Entry{} |> Map.keys() |> Enum.drop(1)
      )
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(account, opts) do
      concat([
        "#Surefire.Accounting.Account<",
        Inspect.Atom.inspect(account.id, opts),
        Inspect.Algebra.break("\n"),
        "[#{length(account.entries)} entries]",
        Inspect.Algebra.break("\n"),
        Kernel.inspect(account.balance),
        Inspect.Algebra.break("\n"),
#        if account.closed do
#          "CLOSED!"
#        else
#          "ONGOING..."
#        end,
        ">"
      ])
    end
  end

  # TODO leverage this in display with Table_rex.
  # See: https://github.com/djm/table_rex/issues/56
  defimpl Table.Reader do
    def init(account) do
      Table.Reader.Enumerable.init_rows(account.entries)
    end
  end
end
