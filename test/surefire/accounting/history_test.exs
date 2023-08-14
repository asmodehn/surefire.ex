defmodule Surefire.Accounting.HistoryTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.{Transaction, History}

  describe "new_transaction_id/0" do
    test "generate a new, always unique, id" do
      uniq_ids = Stream.repeatedly(&History.new_transaction_id/0)
      # TODO : play with random, to test more deeply ?
      assert length(uniq_ids |> Enum.take(512)) ==
               length(uniq_ids |> Stream.uniq() |> Enum.take(512))
    end
  end

  describe "commit/2" do
    test "stores a balanced transaction in the history" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)

      assert Transaction.verify_balanced(t)

      h = %History{}

      assert h.transactions == %{}

      {:ok, %History{transactions: committed}} = History.commit(h, "transac_id", t)

      assert "transac_id" in Map.keys(committed)
      assert committed["transac_id"].description == "test description"
      assert committed["transac_id"].debit == [test_account_a: 42]
      assert committed["transac_id"].credit == [test_account_b: 42]
    end

    test "errors if an unbalanced transaction is passed in" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 33)

      assert not Transaction.verify_balanced(t)

      {:error, :unbalanced_transaction} = History.commit(%History{}, t, "transac_id")
    end

    test "errors if an existing key is passed in" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)

      assert Transaction.verify_balanced(t)

      assert %History{"transac_id" => "fake_transaction"}
             |> History.commit("transac_id", t) ==
               {:error, :existing_transaction_id}
    end

    test "implicitely adds current date if nil in transaction" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)

      assert Transaction.verify_balanced(t)
      assert is_nil(t.date)

      h = %History{}

      assert h.transactions == %{}

      {:ok, %History{transactions: committed}} = History.commit(h, "transac_id", t)
      assert not is_nil(committed["transac_id"].date)
    end

    test "keeps date in transaction if already existing" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)
        |> Transaction.with_current_date(fn -> ~U[2021-02-03 04:05:06.789Z] end)

      assert Transaction.verify_balanced(t)
      assert not is_nil(t.date)

      h = %History{}

      assert h.transactions == %{}

      {:ok, %History{transactions: committed}} = History.commit(h, "transac_id", t)
      assert committed["transac_id"].date == ~U[2021-02-03 04:05:06.789Z]
    end
  end
end
