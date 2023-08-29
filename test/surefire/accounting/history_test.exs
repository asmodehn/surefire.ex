defmodule Surefire.Accounting.HistoryTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Surefire.Accounting.{Transaction, History}

  describe "new_transaction_id/1" do
    test "generate ulid, increasing monotonically" do
      ulid_list =
        History.new()
        |> Stream.unfold(&History.new_transaction_id/1)
        |> Enum.take(5)

      assert ulid_list == ulid_list |> Enum.sort(&</2)
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

      {:error, :unbalanced_transaction} = History.commit(%History{}, "transac_id", t)
    end

    test "errors if an existing key is passed in" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)

      assert Transaction.verify_balanced(t)

      assert %History{transactions: %{"transac_id" => Transaction.build("existing transaction")}}
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

  describe "transactions_from/2" do
    test "returns a partial history with transactions from a certain id (included)" do
      t1 =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 1)
        |> Transaction.with_credit(:test_account_b, 1)

      t2 =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 2)
        |> Transaction.with_credit(:test_account_b, 2)

      t3 =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 3)
        |> Transaction.with_credit(:test_account_b, 3)

      with {id1, h} <- History.new_transaction_id(History.new()),
           {:ok, hh} <- History.commit(h, id1, t1),
           {id2, hhh} <- History.new_transaction_id(hh),
           {:ok, hhhh} <- History.commit(hhh, id2, t2),
           {id3, hhhhh} <- History.new_transaction_id(hhhh),
           {:ok, hhhhhh} <- History.commit(hhhhh, id3, t3) do
        t1c = hh.transactions[id1]
        t2c = hhhh.transactions[id2]
        t3c = hhhhhh.transactions[id3]

        assert History.transactions_from(hhhhhh, id3) == %History{transactions: %{id3 => t3c}}

        assert History.transactions_from(hhhhhh, id2) == %History{
                 transactions: %{
                   id2 => t2c,
                   id3 => t3c
                 }
               }

        assert History.transactions_from(hhhhhh, id1) == %History{
                 transactions: %{
                   id1 => t1c,
                   id2 => t2c,
                   id3 => t3c
                 }
               }

        assert hhhhhh.transactions == %{
                 id1 => t1c,
                 id2 => t2c,
                 id3 => t3c
               }
      end
    end
  end
end
