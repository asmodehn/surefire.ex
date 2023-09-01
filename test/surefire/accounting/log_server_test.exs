defmodule Surefire.Accounting.LogServerTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.{LogServer, History, Transaction}

  describe "start_link/1" do
    test "starts the Accounting server" do
      {:ok, pid} = LogServer.start_link()

      assert Process.alive?(pid)
    end
  end

  describe "chunk/2" do
    setup do
      {:ok, pid} = LogServer.start_link()

      LogServer.open_account(pid, self(), :alice)
      LogServer.open_account(pid, self(), :bob)

      LogServer.open_account(pid, self(), :charlie)
      %{history_srv: pid}
    end

    test "retrieves partial history from the accounting Server history",
         %{history_srv: history_srv} do
      t1 =
        Transaction.build("Transfer 42 from alice to bob")
        |> Transaction.with_debit(self(), :alice, 42)
        |> Transaction.with_credit(self(), :bob, 42)

      t1id = LogServer.commit(history_srv, t1)

      t2 =
        Transaction.build("Transfer 33 from bob to charlie")
        |> Transaction.with_debit(self(), :bob, 33)
        |> Transaction.with_credit(self(), :charlie, 33)

      t2id = LogServer.commit(history_srv, t2)

      t3 =
        Transaction.build("Transfer 51 from alice to charlie")
        |> Transaction.with_debit(self(), :alice, 51)
        |> Transaction.with_credit(self(), :charlie, 51)

      t3id = LogServer.commit(history_srv, t3)

      %History.Chunk{
        from: ^t2id,
        until: ^t3id,
        transactions: retrieved
      } = history_srv |> LogServer.chunk(from: t2id)

      assert retrieved[t1id] == nil

      %Transaction{
        description: t2_descr,
        debit: t2_debits,
        credit: t2_credits
      } = retrieved[t2id]

      assert t2_descr == "Transfer 33 from bob to charlie"
      assert t2_debits == %{self() => [bob: 33]}
      assert t2_credits == %{self() => [charlie: 33]}

      %Transaction{
        description: t3_descr,
        debit: t3_debits,
        credit: t3_credits
      } = retrieved[t3id]

      assert t3_descr == "Transfer 51 from alice to charlie"
      assert t3_debits == %{self() => [alice: 51]}
      assert t3_credits == %{self() => [charlie: 51]}
    end
  end

  describe "last_committed_id" do
    setup do
      {:ok, pid} = LogServer.start_link()

      LogServer.open_account(pid, self(), :alice)
      LogServer.open_account(pid, self(), :bob)
      %{accounting_srv: pid}
    end

    test "return the last committed transaction id",
         %{accounting_srv: accounting_srv} do
      t1 =
        Transaction.build("Transfer 42 from :alice to :bob")
        |> Transaction.with_debit(self(), :alice, 42)
        |> Transaction.with_credit(self(), :bob, 42)

      t1id = LogServer.commit(accounting_srv, t1)

      assert LogServer.last_committed(accounting_srv) == t1id
    end
  end

  describe "commit/4" do
    setup do
      {:ok, pid} = LogServer.start_link()

      LogServer.open_account(pid, self(), :alice)
      LogServer.open_account(pid, self(), :bob)
      %{accounting_srv: pid}
    end

    test "records the transaction in the Accounting server history",
         %{accounting_srv: accounting_srv} do
      LogServer.accounts(accounting_srv, self())

      t1 =
        Transaction.build("Transfer 42 from alice to bob")
        |> Transaction.with_debit(self(), :alice, 42)
        |> Transaction.with_credit(self(), :bob, 42)

      tid = LogServer.commit(accounting_srv, t1)

      # TODO : test date, once the date function is exposed in history server...
      %Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = LogServer.chunk(accounting_srv).transactions[tid]

      assert description == "Transfer 42 from alice to bob"
      assert debits == %{self() => [alice: 42]}
      assert credits == %{self() => [bob: 42]}
    end

    test "prevent recording if one of the debit accounts doesnt exist",
         %{accounting_srv: accounting_srv} do
      LogServer.accounts(accounting_srv, self())

      t1 =
        Transaction.build("Transfer 42 from alice to bob")
        |> Transaction.with_debit(self(), :charlie, 42)
        |> Transaction.with_credit(self(), :bob, 42)

      assert_raise(LogServer.UnknownAccount, fn ->
        LogServer.commit(accounting_srv, t1)
      end)
    end

    test "prevent recording if one of the credit accounts doesnt exist",
         %{accounting_srv: accounting_srv} do
      LogServer.accounts(accounting_srv, self())

      t1 =
        Transaction.build("Transfer 42 from alice to bob")
        |> Transaction.with_debit(self(), :alice, 42)
        |> Transaction.with_credit(self(), :charlie, 42)

      assert_raise(LogServer.UnknownAccount, fn ->
        LogServer.commit(accounting_srv, t1)
      end)
    end

    test "prevent recording if the transaction is unbalanced",
         %{accounting_srv: accounting_srv} do
      LogServer.accounts(accounting_srv, self())

      t1 =
        Transaction.build("Transfer 42 from alice to bob")
        |> Transaction.with_debit(self(), :alice, 42)
        |> Transaction.with_credit(self(), :bob, 43)

      assert_raise(LogServer.UnbalancedTransaction, fn ->
        LogServer.commit(accounting_srv, t1)
      end)
    end
  end

  describe "open_account/3" do
    setup do
      {:ok, pid} = LogServer.start_link()

      %{accounting_srv: pid}
    end

    test "opens an account and accepts matching transactions",
         %{accounting_srv: pid} do
      :ok = LogServer.open_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == [:test_account]
      # TODO : test transactions
    end
  end

  # TODO: maybe review account management API ?
  describe "accounts/2" do
    setup do
      {:ok, pid} = LogServer.start_link()

      %{accounting_srv: pid}
    end

    test "list known accounts by the LogServer that are currently open",
         %{accounting_srv: pid} do
      :ok = LogServer.open_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == [:test_account]

      :ok = LogServer.close_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == nil
    end
  end

  describe "close_account/3" do
    setup do
      {:ok, pid} = LogServer.start_link()

      %{accounting_srv: pid}
    end

    test "closes an account and refuses matching transactions",
         %{accounting_srv: pid} do
      :ok = LogServer.open_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == [:test_account]

      :ok = LogServer.close_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == nil
    end
  end
end
