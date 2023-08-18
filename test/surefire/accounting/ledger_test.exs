defmodule Surefire.Accounting.Ledger.BalanceTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Ledger.Balance
  alias Surefire.Accounting.Transaction

  describe "update/2" do
    test "updates a balance debit and credit values" do
      assert %Balance{}
             |> Balance.update(%Transaction.Entry{
               debit: 42,
               credit: 51
             }) ==
               %Balance{debits: 42, credits: 51}

      assert %Balance{debits: 33, credits: 33}
             |> Balance.update(%Transaction.Entry{
               debit: 42,
               credit: 51
             }) ==
               %Balance{debits: 33 + 42, credits: 33 + 51}
    end
  end
end

defmodule Surefire.Accounting.LedgerTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Ledger
  alias Surefire.Accounting.Transaction

  describe "new/2" do
    test "creates a new ledger, with opening debit and credits balance" do
      ledger = Ledger.new(:fake_account_id, 42, 51)
      assert ledger.balance == %Ledger.Balance{debits: 42, credits: 51}
    end
  end

  describe "append/2" do
    test "appends an entry to the ledger, and updates the balance" do
      test_entry = %Transaction.Entry{
        transaction_id: "transac_id",
        account: nil,
        date: nil,
        description: "",
        debit: 42,
        credit: 51
      }

      assert %Ledger{} |> Ledger.append(test_entry) == %Ledger{
               entries: [test_entry],
               balance: %Ledger.Balance{debits: 42, credits: 51}
             }
    end

    test "errors if the entry doesnt belong to a committed transaction" do
      test_entry = %Transaction.Entry{
        transaction_id: nil,
        account: nil,
        date: nil,
        description: "",
        debit: 0,
        credit: 0
      }

      assert_raise(FunctionClauseError, fn -> %Ledger{} |> Ledger.append(test_entry) end)
    end
  end

  describe "reflect/2" do
  end
end
