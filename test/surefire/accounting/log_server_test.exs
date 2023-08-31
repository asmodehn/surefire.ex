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

      %{history_srv: pid}
    end

    test "retrieves partial history from the accounting Server history",
         %{history_srv: history_srv} do
      t1id = LogServer.transfer(:alice, :bob, 42, history_srv)
      t2id = LogServer.transfer(:bob, :charlie, 33, history_srv)
      t3id = LogServer.transfer(:alice, :charlie, 51, history_srv)

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
      assert t2_debits == [bob: 33]
      assert t2_credits == [charlie: 33]

      %Transaction{
        description: t3_descr,
        debit: t3_debits,
        credit: t3_credits
      } = retrieved[t3id]

      assert t3_descr == "Transfer 51 from alice to charlie"
      assert t3_debits == [alice: 51]
      assert t3_credits == [charlie: 51]
    end
  end

  describe "last_committed_id" do
    setup do
      {:ok, pid} = LogServer.start_link()

      %{accounting_srv: pid}
    end

    test "return the last committed transaction id",
         %{accounting_srv: accounting_srv} do
      t1id = LogServer.transfer(:alice, :bob, 42, accounting_srv)

      assert LogServer.last_committed(accounting_srv) == t1id
    end
  end

  describe "transfer/4" do
    setup do
      {:ok, pid} = LogServer.start_link()

      %{accounting_srv: pid}
    end

    test "records the transaction in the Accounting server history",
         %{accounting_srv: accounting_srv} do
      tid = LogServer.transfer(:alice, :bob, 42, accounting_srv)

      # TODO : test date, once the date function is exposed in history server...
      %Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = LogServer.chunk(accounting_srv).transactions[tid]

      assert description == "Transfer 42 from alice to bob"
      assert debits == [alice: 42]
      assert credits == [bob: 42]
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
