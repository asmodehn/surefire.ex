defmodule Surefire.Accounting.BookTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.Book

  describe "add_account/2" do
    test "adds an account to the chart of account on the book" do
      a =  Account.new_debit(:alice, "Alice Debit", 42)
      b = Book.new()
      |> Book.add_account( a      )

         assert b.chart[:alice] ==  a

    end
  end


  describe "reflect/3" do
    test "records a transaction in the book, by splitting entries into the various accounts" do

      a =  Account.new_debit(:alice, "Alice Assets", 42)
      b =  Account.new_debit(:bob, "Bob's Assets", 42)

      book = Book.new() |> Book.add_account(a) |> Book.add_account(b)

      t = Transaction.build("Alice to Bob")
      |> Transaction.with_credit(:alice, 12)  # (decrease debit account)
      |> Transaction.with_debit(:bob, 12)  # (increase debit account)

      updated_book = book |> Book.reflect(t, "a2b_fake_ID")

      updated_a = updated_book.chart[:alice]
      updated_b = updated_book.chart[:bob]

      assert updated_a.entries == [
               %Transaction.Entry{account: :alice,
                 transaction_id: "a2b_fake_ID",
                 description: "Alice to Bob",
                 debit: 0,
                 credit: 12}]
      assert updated_b.entries == [
               %Transaction.Entry{account: :bob,
                 transaction_id: "a2b_fake_ID",
                 description: "Alice to Bob",
                 debit: 12,
                 credit: 0}]

      assert Account.balance(updated_a) == 30
      assert Account.balance(updated_b) == 54

# TODO : fix API :
# - different names for types of account ?
# - different transaction/entry sections ?
# - different perspective, outside/inside for switching debit/credit ??

    end
  end

  describe "reflect/2" do
    # TODO :from history, all transactions have an id and a date.
  end


end