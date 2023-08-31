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
    # TODO : verify transaction is refused if one account doesnt exists
    # TODO : verify transaction is accepted if all accounts exist
    test "stores a balanced transaction in the history and remember its id" do
      t =
        Transaction.build("test description")
        |> Transaction.with_debit(:test_account_a, 42)
        |> Transaction.with_credit(:test_account_b, 42)

      assert Transaction.verify_balanced(t)

      h = %History{}

      assert h.transactions == %{}

      {:ok, %History{transactions: committed} = up_hist} = History.commit(h, "transac_id", t)

      assert "transac_id" in Map.keys(committed)
      assert up_hist.last_committed_id == "transac_id"
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

  describe "chunk/2" do
    setup do
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

        %{history: hhhhhh, ids: [id3, id2, id1], transactions: [t3c, t2c, t1c]}
      end
    end

    test "returns a history chunk between bounds, bounds included",
         %{history: history, ids: [id3, id2, id1], transactions: [t3c, t2c, t1c]} do
      assert history.transactions == %{
               id1 => t1c,
               id2 => t2c,
               id3 => t3c
             }

      last_match = %History.Chunk{
        from: id3,
        until: id3,
        transactions: %{id3 => t3c}
      }

      assert History.chunk(history, from: id3) == last_match
      assert History.chunk(history, from: id3, until: id3) == last_match

      middle_last = %History.Chunk{
        from: id2,
        until: id3,
        transactions: %{
          id2 => t2c,
          id3 => t3c
        }
      }

      assert History.chunk(history, from: id2) == middle_last
      assert History.chunk(history, from: id2, until: id3) == middle_last

      all_three = %History.Chunk{
        from: id1,
        until: id3,
        transactions: %{
          id1 => t1c,
          id2 => t2c,
          id3 => t3c
        }
      }

      assert History.chunk(history, from: id1) == all_three
      assert History.chunk(history, until: id3) == all_three
      assert History.chunk(history, from: id1, until: id3) == all_three

      first_middle = %History.Chunk{
        from: id1,
        until: id2,
        transactions: %{
          id1 => t1c,
          id2 => t2c
        }
      }

      assert History.chunk(history, until: id2) == first_middle
      assert History.chunk(history, from: id1, until: id2) == first_middle

      first_match = %History.Chunk{
        from: id1,
        until: id1,
        transactions: %{id1 => t1c}
      }

      assert History.chunk(history, until: id1) == first_match
      assert History.chunk(history, from: id1, until: id1) == first_match
    end
  end

  describe "open_account/2" do
    test "register another account in the history for this pid" do
      h = History.new() |> History.open_account(self(), :new_account)

      assert self() in Map.keys(h.accounts)
      assert h.accounts[self()] == [:new_account]

      h_updated = h |> History.open_account(self(), :another_one)

      assert h_updated.accounts[self()] == [:another_one, :new_account]
    end

    test "prevent account unicity for a pid" do
      h = History.new() |> History.open_account(self(), :new_account)

      assert self() in Map.keys(h.accounts)
      assert h.accounts[self()] == [:new_account]

      h_updated = h |> History.open_account(self(), :new_account)

      assert h_updated.accounts[self()] == [:new_account]
    end
  end

  describe "close_account/2" do
    test "unregister the account in the history" do
      h = History.new() |> History.open_account(self(), :new_account)

      assert self() in Map.keys(h.accounts)
      assert h.accounts[self()] == [:new_account]

      h_updated = h |> History.open_account(self(), :another_one)

      assert h_updated.accounts[self()] == [:another_one, :new_account]

      h_again = h_updated |> History.close_account(self(), :another_one)

      assert h_again.accounts[self()] == [:new_account]

      h_empty = h_again |> History.close_account(self(), :new_account)

      assert self() not in Map.keys(h_empty.accounts)
    end
  end
end
