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

  describe "open_debit_account" do
    test "adds a debit account on the book" do
      b =
        Book.new()
        |> Book.open_debit_account(:alice, "Alice Debit")

      assert b.accounts[:alice] == Account.new_debit(:alice, "Alice Debit")
    end
  end

  describe "open_credit_account" do
    test "adds a credit account on the book" do
      b =
        Book.new()
        |> Book.open_credit_account(:alice, "Alice Credit")

      assert b.accounts[:alice] == Account.new_credit(:alice, "Alice Credit")
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

    setup do
      book =
        Book.new()
        |> Book.open_debit_account(:test_debit, "test debit account")
        |> Book.open_credit_account(:test_credit, "test credit account")

      %{book: book}
    end

    # TODO : raise error on commit in history ! here is to late -> ignore (partial read)...
    test "raise error if account in transaction doesnt exist", %{book: book} do
      # Note: unbalanced Transaction can be reflected
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "debit transaction for this account",
        debit: [unknown: 42],
        credit: []
      }

      assert_raise(RuntimeError, fn ->
        book |> Book.reflect(test_transact, "fakeID")
      end)
    end

    test "add debit entry on matching debit account and increase its balance",
         %{book: book} do
      # Note: unbalanced Transaction can be reflected
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "debit transaction for this account",
        debit: [test_debit: 42],
        credit: []
      }

      updated_book = book |> Book.reflect(test_transact, "fakeID")

      assert updated_book.accounts[:test_debit]
             |> Account.balance() == 42
    end

    test "add credit entry on matching debit account and decrease its balance",
         %{book: book} do
      # Note: unbalanced Transaction can be reflected
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "credit transaction for this account",
        debit: [],
        credit: [test_debit: 42]
      }

      updated_book = book |> Book.reflect(test_transact, "fakeID")

      assert updated_book.accounts[:test_debit]
             |> Account.balance() == -42
    end

    test "add debit entry on matching credit account and decrease its balance",
         %{book: book} do
      # Note: unbalanced Transaction can be reflected
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "credit transaction for this account",
        debit: [test_credit: 42],
        credit: []
      }

      updated_book = book |> Book.reflect(test_transact, "fakeID")

      assert updated_book.accounts[:test_credit]
             |> Account.balance() == -42
    end

    test "add credit entry on matching credit account and increase its balance",
         %{book: book} do
      # Note: unbalanced Transaction can be reflected
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "credit transaction for this account",
        debit: [],
        credit: [test_credit: 42]
      }

      updated_book = book |> Book.reflect(test_transact, "fakeID")

      assert updated_book.accounts[:test_credit]
             |> Account.balance() == 42
    end

    test "if transaction_id >= last_transaction_id, book is unchanged",
         %{book: book} do
      test_transact = %Transaction{
        date: ~U[2021-02-03 04:05:06.789Z],
        description: "debit transaction for this account",
        debit: [test_debit: 42],
        credit: []
      }

      ignored_transact = %Transaction{
        date: ~U[2021-02-03 04:05:07.891Z],
        description: "debit transaction for this account",
        debit: [test_debit: 51],
        credit: []
      }

      updated_book =
        book
        |> Book.reflect(test_transact, "fakeID")

      # same id doesnt change the book
      assert updated_book |> Book.reflect(ignored_transact, "fakeID") == updated_book

      assert "absentID" < "fakeID"
      # lower id doesnt change the book
      assert updated_book |> Book.reflect(ignored_transact, "absentID") == updated_book
    end
  end

  describe "reflect/2" do
    # TODO :from history, all transactions have an id and a date.
  end
end
