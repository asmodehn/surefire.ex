defmodule Surefire.Accounting.BookTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.Account
  alias Surefire.Accounting.Transaction
  alias Surefire.Accounting.Book

  describe "add_external/2" do
    test "adds an external account to the accounts on the book" do
      a = Account.new_debit(:alice, "Alice Debit", 42)

      b =
        Book.new()
        |> Book.add_external(a)

      assert b.externals[:alice] == a
    end
  end

  describe "reflect/3" do
    test "records a transaction in the book, by splitting entries into the various accounts" do
      a = Account.new_debit(:alice, "Alice Assets", 0)

      book = Book.new(100) |> Book.add_external(a)

      t = Transaction.funding_to(42, a)

      updated_book = book |> Book.reflect(t, "a2b_fake_ID")

      updated_a = updated_book.externals[:alice]

      assert updated_a.entries == [
               %Transaction.Entry{
                 account: :alice,
                 transaction_id: "a2b_fake_ID",
                 description: "Funding to Alice Assets",
                 debit: 42,
                 credit: 0
               }
             ]

      assert updated_book.assets.entries == [
               %Transaction.Entry{
                 account: :assets,
                 transaction_id: "a2b_fake_ID",
                 description: "Funding to Alice Assets",
                 debit: 0,
                 credit: 42
               }
             ]

      assert Account.balance(updated_a) == 42
      assert Account.balance(updated_book.assets) == 100 - 42

      # TODO : fix API :
      # - different names / modules for types of account ?
      # - different transaction/entry sections ?
      # - different perspective, outside/inside for switching debit/credit ??
    end
  end

  describe "reflect/2" do
    # TODO :from history, all transactions have an id and a date.
  end
end
