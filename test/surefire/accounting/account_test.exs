defmodule Surefire.Accounting.AccountTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.Ledger
  alias Surefire.Accounting.Transaction

  describe "new_debit/1" do
    test "creates a new account with an opening balance of 0" do
      assert Account.new_debit(:debit_account, "test debit account") == %Account{
               id: :debit_account,
               name: "test debit account",
               type: :debit,
               ledger: Ledger.new(:debit_account)
             }
    end
  end

  describe "new_debit/2" do
    test "creates a new account with a correct opening balance" do
      %Account{
        id: :debit_account,
        name: "test debit account",
        type: :debit,
        ledger: debit_ledger
      } = Account.new_debit(:debit_account, "test debit account", 42)

      assert debit_ledger.balance == %Ledger.Balance{debits: 42, credits: 0}

      %Account{
        id: :debit_account,
        name: "test debit account",
        type: :debit,
        ledger: credit_ledger
      } = Account.new_debit(:debit_account, "test debit account", -51)

      assert credit_ledger.balance == %Ledger.Balance{debits: 0, credits: 51}
    end
  end

  describe "new_credit/1" do
    test "creates a new account with an opening balance of 0" do
      assert Account.new_credit(:credit_account, "test credit account") == %Account{
               id: :credit_account,
               name: "test credit account",
               type: :credit,
               ledger: Ledger.new(:credit_account)
             }
    end
  end

  describe "new_credit/2" do
    test "creates a new account with a correct opening balance" do
      %Account{
        id: :credit_account,
        name: "test credit account",
        type: :credit,
        ledger: credit_ledger
      } = Account.new_credit(:credit_account, "test credit account", 42)

      assert credit_ledger.balance == %Ledger.Balance{debits: 0, credits: 42}

      %Account{
        id: :credit_account,
        name: "test credit account",
        type: :credit,
        ledger: debit_ledger
      } = Account.new_credit(:credit_account, "test credit account", -51)

      assert debit_ledger.balance == %Ledger.Balance{debits: 51, credits: 0}
    end
  end

  describe "balance/1" do
    test "on new accounts, returns the opening balance" do
      dacc = Account.new_debit(:test_debit, "test debit account", 33)
      assert Account.balance(dacc) == 33

      cacc = Account.new_credit(:test_credit, "test credit account", 33)
      assert Account.balance(cacc) == 33
    end

    test "returns the ledger balance as a relative integer, depending on the type of the account" do
      l = %Ledger{balance: %Ledger.Balance{debits: 42, credits: 51}}

      dacc = Account.new_debit(:test_debit, "test debit account", 0)

      assert %{dacc | ledger: l}
             |> Account.balance() == 42 - 51

      cacc = Account.new_credit(:test_credit, "test credit account", 0)

      assert %{cacc | ledger: l}
             |> Account.balance() == 51 - 42
    end
  end

  describe "reflect/3" do
    setup do
      debit_account = Account.new_debit(:test_debit, "test debit account")
      credit_account = Account.new_credit(:test_credit, "test credit account")

      %{debit_account: debit_account, credit_account: credit_account}
    end

    test "if debit on the debit account, add matching entry to ledger and update its balance",
         %{debit_account: debit_account} do
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "debit transaction for this account",
        debit: [test_debit: 42, to_ignore: 51],
        credit: [to_ignore: 33]
      }

      %Account{
        id: :test_debit,
        name: "test debit account",
        type: :debit,
        ledger: ledger
      } = debit_account |> Account.reflect(test_transact, "fakeID")

      assert ledger.balance == %Ledger.Balance{debits: 42, credits: 0}
    end

    test "if credit on the debit account, add matching entry to ledger and update its balance",
         %{debit_account: debit_account, credit_account: _} do
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "credit transaction for this account",
        debit: [to_ignore: 51],
        credit: [to_ignore: 33, test_debit: 42]
      }

      %Account{
        id: :test_debit,
        name: "test debit account",
        type: :debit,
        ledger: ledger
      } = debit_account |> Account.reflect(test_transact, "fakeID")

      assert ledger.balance == %Ledger.Balance{debits: 0, credits: 42}
    end

    test "if debit on the credit account, add matching entry to ledger and update its balance",
         %{debit_account: _, credit_account: credit_account} do
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "credit transaction for this account",
        debit: [to_ignore: 51, test_credit: 42],
        credit: [to_ignore: 33]
      }

      %Account{
        id: :test_credit,
        name: "test credit account",
        type: :credit,
        ledger: ledger
      } = credit_account |> Account.reflect(test_transact, "fakeID")

      assert ledger.balance == %Ledger.Balance{debits: 42, credits: 0}
    end

    test "if credit on the credit account, add matching entry to ledger and update its balance",
         %{debit_account: _, credit_account: credit_account} do
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "credit transaction for this account",
        debit: [to_ignore: 51],
        credit: [test_credit: 42, to_ignore: 33]
      }

      %Account{
        id: :test_credit,
        name: "test credit account",
        type: :credit,
        ledger: ledger
      } = credit_account |> Account.reflect(test_transact, "fakeID")

      assert ledger.balance == %Ledger.Balance{debits: 0, credits: 42}
    end

    test "if transaction_id > last_transaction_id, new transaction is ignored",
         %{debit_account: debit_account} do
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "debit transaction for this account",
        debit: [test_debit: 42, to_ignore: 51],
        credit: [to_ignore: 33]
      }

      ignored_transact = %Transaction{
        date: ~U[2021-02-03 04:05:07.891Z],
        description: "debit transaction for this account",
        debit: [test_debit: 51, to_ignore: 33],
        credit: [to_ignore: 33]
      }

      assert "absentID" <= "fakeID"

      %Account{
        id: :test_debit,
        name: "test debit account",
        type: :debit,
        ledger: ledger
      } =
        debit_account
        |> Account.reflect(test_transact, "fakeID")
        |> Account.reflect(ignored_transact, "absentID")

      # the debit on :test_debit of 51 has been ignored.
      assert ledger.balance == %Ledger.Balance{debits: 42, credits: 0}
    end
  end
end
