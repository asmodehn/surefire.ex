defmodule Surefire.Accounting.LogServerTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.{LogServer, History, Transaction}

  # childspec for logserver, passing a name,
  # to not conflict with application's logserver.
  @logserver_spec %{
    id: LogServer,
    start: {LogServer, :start_link, [[], [name: :logserver_in_logservertest]]}
  }

  describe "start_link/2" do
    @tag :current
    test "starts the Accounting server with the passed history and name" do
      proc_name = :logserver_in_logservertest
      h = History.new()
      {:ok, pid} = LogServer.start_link(h, name: proc_name)

      assert Process.whereis(proc_name) == pid
      assert :sys.get_state(proc_name) == h
    end

    test "creates a new history if [] is passed as initial argument" do
      proc_name = :logserver_in_logservertest

      {:ok, pid} = LogServer.start_link([], name: proc_name)

      assert Process.whereis(proc_name) == pid
      %History{transactions: ts, last_committed_id: lci} = :sys.get_state(proc_name)

      assert ts == %{}
      assert lci == nil
    end
  end

  describe "chunk/2" do
    setup do
      with pid <- start_supervised!(@logserver_spec) do
        LogServer.open_account(pid, self(), :alice)
        LogServer.open_account(pid, self(), :bob)

        LogServer.open_account(pid, self(), :charlie)
        %{history_srv: pid}
      end
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
      with pid <- start_supervised!(@logserver_spec) do
        LogServer.open_account(pid, self(), :alice)
        LogServer.open_account(pid, self(), :bob)
        %{accounting_srv: pid}
      end
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
      with pid <- start_supervised!(@logserver_spec) do
        LogServer.open_account(pid, self(), :alice)
        LogServer.open_account(pid, self(), :bob)
        %{accounting_srv: pid}
      end
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

      assert_raise(LogServer.UnknownAccounts, fn ->
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

      assert_raise(LogServer.UnknownAccounts, fn ->
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
      with pid <- start_supervised!(@logserver_spec),
           useless_srv <- Process.spawn(fn -> [] end, [:link]) do
        %{accounting_srv: pid, fake_pid: useless_srv}
      end
    end

    test "opens an account on same ledger and accepts matching transactions",
         %{accounting_srv: pid} do
      :ok = LogServer.open_account(pid, self(), :test_send)
      :ok = LogServer.open_account(pid, self(), :test_receive)

      assert :test_send in LogServer.accounts(pid, self())
      assert :test_receive in LogServer.accounts(pid, self())

      t_test =
        Transaction.build("test transaction")
        |> Transaction.with_debit(self(), :test_send, 42)
        |> Transaction.with_credit(self(), :test_receive, 42)

      LogServer.commit(pid, t_test)
    end

    test "opens an account on another ledger and accepts matching transactions",
         %{accounting_srv: pid, fake_pid: useless_srv} do
      :ok = LogServer.open_account(pid, self(), :test_send)
      :ok = LogServer.open_account(pid, useless_srv, :test_receive)

      assert :test_send in LogServer.accounts(pid, self())
      assert :test_receive in LogServer.accounts(pid, useless_srv)

      t_test =
        Transaction.build("test transaction")
        |> Transaction.with_debit(self(), :test_send, 42)
        |> Transaction.with_credit(useless_srv, :test_receive, 42)

      LogServer.commit(pid, t_test)
    end
  end

  # TODO: maybe review account management API ?
  describe "accounts/2" do
    setup do
      with pid <- start_supervised!(@logserver_spec) do
        %{accounting_srv: pid}
      end
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
      with pid <- start_supervised!(@logserver_spec) do
        %{accounting_srv: pid}
      end
    end

    test "closes an account and refuses matching transactions",
         %{accounting_srv: pid} do
      :ok = LogServer.open_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == [:test_account]

      :ok = LogServer.close_account(pid, self(), :test_account)

      assert LogServer.accounts(pid, self()) == nil

      t_test =
        Transaction.build("test transaction")
        |> Transaction.with_debit(self(), :test_account, 42)
        |> Transaction.with_credit(self(), :test_account, 42)

      assert_raise(LogServer.UnknownAccounts, fn ->
        LogServer.commit(pid, t_test)
      end)
    end
  end
end
