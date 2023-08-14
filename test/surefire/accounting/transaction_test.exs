defmodule Surefire.Accounting.TransactionTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Transaction

  describe "build/1" do
    test "creates a Transaction struct with description" do
      t = Transaction.build("test description")
      assert t == %Transaction{description: "test description"}
      assert t.debit == []
      assert t.credit == []
      assert t.date == nil
    end

    test "creates a Transaction that contains no entries" do
      t = Transaction.build("test description")
      assert Transaction.as_entries(t, "fake_id") == []
    end
  end

  describe "with_debit/3" do
    test "add a debit entry in the list" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)

      assert Transaction.as_entries(t, "fake_id") == [
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_a,
                 date: nil,
                 description: "test description",
                 debit: 42,
                 credit: 0
               }
             ]
    end
  end

  describe "with_debits/2" do
    test "add a list of debit entries in the list" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debits(test_account_a: 42, test_account_b: 51)

      assert Transaction.as_entries(t, "fake_id") == [
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_a,
                 date: nil,
                 description: "test description",
                 debit: 42,
                 credit: 0
               },
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_b,
                 date: nil,
                 description: "test description",
                 debit: 51,
                 credit: 0
               }
             ]
    end
  end

  describe "with_credit/3" do
    test "add a credit entry in the list" do
      t =
        Transaction.build("test description")
        |> Transaction.with_credit(:test_account_a, 42)

      assert Transaction.as_entries(t, "fake_id") == [
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_a,
                 date: nil,
                 description: "test description",
                 debit: 0,
                 credit: 42
               }
             ]
    end
  end

  describe "with_credits/2" do
    test "add a list of credit entries in the list" do
      t =
        Transaction.build("test description")
        |> Transaction.with_credits(test_account_a: 42, test_account_b: 51)

      assert Transaction.as_entries(t, "fake_id") == [
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_a,
                 date: nil,
                 description: "test description",
                 debit: 0,
                 credit: 42
               },
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_b,
                 date: nil,
                 description: "test description",
                 debit: 0,
                 credit: 51
               }
             ]
    end
  end

  describe "with_date/1" do
    test "adds date to the transaction, that gets reflected in the corresponding entry" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_current_date(fn -> ~U[2021-02-03 04:05:06.789Z] end)

      assert Transaction.as_entries(t, "fake_id") == [
               %Transaction.Entry{
                 transaction_id: "fake_id",
                 account: :test_account_a,
                 date: ~U[2021-02-03 04:05:06.789Z],
                 description: "test description",
                 debit: 42,
                 credit: 0
               }
             ]
    end
  end

  describe "verify_balanced/1" do
    test "return true if the transaction is balanced (debits amount == credits amount )" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)

      assert Transaction.verify_balanced(t) == true
    end

    test "return false if the transaction is not balanced(debits amount != credits amount)" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 33)

      assert Transaction.verify_balanced(t) == false
    end
  end
end
