defmodule Surefire.Accounting.Account.BalanceTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Account.Balance
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

defmodule Surefire.Accounting.AccountTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.Transaction

  describe "new_debit/1" do
    test "creates a new account with an opening balance of 0" do
      assert Account.new_debit(:debit_account, "test debit account") == %Account{
               id: :debit_account,
               name: "test debit account",
               type: :debit
             }
    end
  end

  describe "new_debit/2" do
    test "creates a new account with a correct opening balance" do
      %Account{
        id: :debit_account,
        name: "test debit account",
        type: :debit,
        balance: balance
      } = Account.new_debit(:debit_account, "test debit account", 42)

      assert balance == %Account.Balance{debits: 42, credits: 0}

      %Account{
        id: :debit_account,
        name: "test debit account",
        type: :debit,
        balance: balance
      } = Account.new_debit(:debit_account, "test debit account", -51)

      assert balance == %Account.Balance{debits: 0, credits: 51}
    end
  end

  describe "new_credit/1" do
    test "creates a new account with an opening balance of 0" do
      assert Account.new_credit(:credit_account, "test credit account") == %Account{
               id: :credit_account,
               name: "test credit account",
               type: :credit
             }
    end
  end

  describe "new_credit/2" do
    test "creates a new account with a correct opening balance" do
      %Account{
        id: :credit_account,
        name: "test credit account",
        type: :credit,
        balance: balance
      } = Account.new_credit(:credit_account, "test credit account", 42)

      assert balance == %Account.Balance{debits: 0, credits: 42}

      %Account{
        id: :credit_account,
        name: "test credit account",
        type: :credit,
        balance: balance
      } = Account.new_credit(:credit_account, "test credit account", -51)

      assert balance == %Account.Balance{debits: 51, credits: 0}
    end
  end

  describe "balance/1" do
    test "on new accounts, returns the opening balance" do
      dacc = Account.new_debit(:test_debit, "test debit account", 33)
      assert Account.balance(dacc) == 33

      cacc = Account.new_credit(:test_credit, "test credit account", 33)
      assert Account.balance(cacc) == 33
    end

    test "returns the balance as a relative integer, depending on the type of the account" do
      dacc = Account.new_debit(:test_debit, "test debit account", 0)

      assert %{dacc | balance: %Account.Balance{debits: 42, credits: 51}}
             |> Account.balance() == 42 - 51

      cacc = Account.new_credit(:test_credit, "test credit account", 0)

      assert %{cacc | balance: %Account.Balance{debits: 42, credits: 51}}
             |> Account.balance() == 51 - 42
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

      assert %Account{} |> Account.append(test_entry) == %Account{
               entries: [test_entry],
               balance: %Account.Balance{debits: 42, credits: 51}
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

      assert_raise(FunctionClauseError, fn -> %Account{} |> Account.append(test_entry) end)
    end
  end
end
