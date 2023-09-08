defmodule Surefire.LedgerServerTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.{History, LedgerServer, LogServer, Account, Transaction}

  # childspec for logserver, passing a name,
  # to not conflict with application's logserver.
  @logserver_spec %{
    id: LogServer,
    start: {LogServer, :start_link, [[], [name: :logserver_in_ledgerservertest]]}
  }

  describe "start_link/1" do
    setup do
      history_pid = start_supervised!(@logserver_spec)

      %{history_pid: history_pid}
    end

    test "starts the Ledger server", %{history_pid: history_pid} do
      {:ok, pid} = LedgerServer.start_link(history_pid)

      assert Process.alive?(pid)
    end
  end

  describe "open_account/3" do
    setup do
      with history_pid <- start_supervised!(@logserver_spec),
           bizserver_pid <- start_supervised!({LedgerServer, history_pid}) do
        %{history_pid: history_pid, biz_server_pid: bizserver_pid}
      end
    end

    test "with :debit, creates a debit account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok = LedgerServer.open_account(bizserver_pid, :test_debit, "Test Debit Account", :debit)

      assert LogServer.accounts(history_pid, bizserver_pid) == [:test_debit]
    end

    test "with :credit, creates a credit account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok = LedgerServer.open_account(bizserver_pid, :test_credit, "Test Credit Account", :credit)
      assert LogServer.accounts(history_pid, bizserver_pid) == [:test_credit]
    end
  end

  describe "close_account/2" do
    setup do
      with history_pid <- start_supervised!(@logserver_spec),
           bizserver_pid <- start_supervised!({LedgerServer, history_pid}) do
        %{history_pid: history_pid, biz_server_pid: bizserver_pid}
      end
    end

    test "closes an existing account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok = LedgerServer.open_account(bizserver_pid, :test_debit, "Test Debit Account", :debit)

      assert LogServer.accounts(history_pid, bizserver_pid) == [:test_debit]

      :ok = LedgerServer.close_account(bizserver_pid, :test_debit)

      assert LogServer.accounts(history_pid, bizserver_pid) == nil
    end
  end

  describe "view/2" do
    setup do
      with history_pid <- start_supervised!(@logserver_spec),
           bizserver_pid <- start_supervised!({LedgerServer, history_pid}) do
        %{history_pid: history_pid, biz_server_pid: bizserver_pid}
      end
    end

    test "return an existing account, reflecting transactions", %{
      biz_server_pid: bizserver_pid
    } do
      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_A, "Test Debit Account A", :debit)

      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_B, "Test Debit Account B", :debit)

      tid =
        LedgerServer.transfer_debit(
          bizserver_pid,
          "Debit Transfer",
          :test_debit_A,
          :test_debit_B,
          42
        )

      %Account{
        id: :test_debit_A,
        name: "Test Debit Account A",
        type: :debit,
        entries: entries_A,
        balance: %Surefire.Accounting.Account.Balance{debits: 0, credits: 42}
      } = LedgerServer.view(bizserver_pid, :test_debit_A)

      # pattern matching for partial match (because of date !)
      [
        %Transaction.Entry{
          transaction_id: ^tid,
          account: :test_debit_A,
          description: "Debit Transfer",
          debit: 0,
          credit: 42
        }
      ] = entries_A

      %Account{
        id: :test_debit_B,
        name: "Test Debit Account B",
        entries: entries_B,
        type: :debit,
        balance: _balance_B
      } = LedgerServer.view(bizserver_pid, :test_debit_B)

      # pattern matching for partial match (because of date !)
      [
        %Transaction.Entry{
          transaction_id: ^tid,
          account: :test_debit_B,
          description: "Debit Transfer",
          debit: 42,
          credit: 0
        }
      ] = entries_B
    end
  end

  describe "balance/2" do
    setup do
      with history_pid <- start_supervised!(@logserver_spec),
           bizserver_pid <- start_supervised!({LedgerServer, history_pid}) do
        %{history_pid: history_pid, biz_server_pid: bizserver_pid}
      end
    end

    test "returns an existing account balance, reflecting transactions", %{
      biz_server_pid: bizserver_pid
    } do
      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_A, "Test Debit Account A", :debit)

      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_B, "Test Debit Account B", :debit)

      _tid =
        LedgerServer.transfer_debit(
          bizserver_pid,
          "Transfer Debit",
          :test_debit_A,
          :test_debit_B,
          42
        )

      assert LedgerServer.balance(bizserver_pid, :test_debit_A) == -42

      assert LedgerServer.balance(bizserver_pid, :test_debit_B) == 42
    end
  end

  describe "transfer_debit/3" do
    setup do
      with history_pid <- start_supervised!(@logserver_spec),
           bizserver_pid <- start_supervised!({LedgerServer, history_pid}) do
        %{history_pid: history_pid, biz_server_pid: bizserver_pid}
      end
    end

    test "transfer a debit from a debit account to another debit account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_A, "Test Debit Account A", :debit)

      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_B, "Test Debit Account B", :debit)

      tid =
        LedgerServer.transfer_debit(
          bizserver_pid,
          "Transfer Debit",
          :test_debit_A,
          :test_debit_B,
          42
        )

      %History.Chunk{
        from: ^tid,
        until: ^tid,
        transactions: transactions
      } = Surefire.Accounting.LogServer.chunk(history_pid, from: tid, to: tid)

      %Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = transactions[tid]

      assert description == "Transfer Debit"
      assert debits[bizserver_pid] == [test_debit_B: 42]
      assert credits[bizserver_pid] == [test_debit_A: 42]

      assert LedgerServer.balance(bizserver_pid, :test_debit_A) == -42
      assert LedgerServer.balance(bizserver_pid, :test_debit_B) == 42
    end

    test "transfer a debit from a credit account to another credit account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok =
        LedgerServer.open_account(bizserver_pid, :test_credit_A, "Test Credit Account A", :credit)

      :ok =
        LedgerServer.open_account(bizserver_pid, :test_credit_B, "Test Credit Account B", :credit)

      tid =
        LedgerServer.transfer_debit(
          bizserver_pid,
          "Transfer Debit",
          :test_credit_A,
          :test_credit_B,
          42
        )

      %History.Chunk{
        from: ^tid,
        until: ^tid,
        transactions: transactions
      } = Surefire.Accounting.LogServer.chunk(history_pid, from: tid, to: tid)

      %Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = transactions[tid]

      assert description == "Transfer Debit"
      assert debits[bizserver_pid] == [test_credit_B: 42]
      assert credits[bizserver_pid] == [test_credit_A: 42]

      # Note :balance is inverted because the type of accounts is credit normal
      assert LedgerServer.balance(bizserver_pid, :test_credit_A) == 42
      assert LedgerServer.balance(bizserver_pid, :test_credit_B) == -42
    end

    test "transfer a debit from a credit account to another debit account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok =
        LedgerServer.open_account(bizserver_pid, :test_credit_A, "Test Credit Account A", :credit)

      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_B, "Test Debit Account B", :debit)

      tid =
        LedgerServer.transfer_debit(
          bizserver_pid,
          "Transfer Debit",
          :test_credit_A,
          :test_debit_B,
          42
        )

      %History.Chunk{
        from: ^tid,
        until: ^tid,
        transactions: transactions
      } = Surefire.Accounting.LogServer.chunk(history_pid, from: tid, to: tid)

      %Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = transactions[tid]

      assert description == "Transfer Debit"
      assert debits[bizserver_pid] == [test_debit_B: 42]
      assert credits[bizserver_pid] == [test_credit_A: 42]

      # Note : both balance are same , since account type is different
      assert LedgerServer.balance(bizserver_pid, :test_credit_A) == 42
      assert LedgerServer.balance(bizserver_pid, :test_debit_B) == 42
    end

    test "transfer a debit from a debit account to another credit account",
         %{history_pid: history_pid, biz_server_pid: bizserver_pid} do
      :ok =
        LedgerServer.open_account(bizserver_pid, :test_debit_A, "Test Debit Account A", :debit)

      :ok =
        LedgerServer.open_account(bizserver_pid, :test_credit_B, "Test Credit Account B", :credit)

      tid =
        LedgerServer.transfer_debit(
          bizserver_pid,
          "Transfer Debit",
          :test_debit_A,
          :test_credit_B,
          42
        )

      %History.Chunk{
        from: ^tid,
        until: ^tid,
        transactions: transactions
      } = Surefire.Accounting.LogServer.chunk(history_pid, from: tid, to: tid)

      %Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = transactions[tid]

      assert description == "Transfer Debit"
      assert debits[bizserver_pid] == [test_credit_B: 42]
      assert credits[bizserver_pid] == [test_debit_A: 42]

      # Note :balance is inverted because the type of accounts is credit normal
      assert LedgerServer.balance(bizserver_pid, :test_debit_A) == -42
      assert LedgerServer.balance(bizserver_pid, :test_credit_B) == -42
    end
  end

  describe "transfer_credit/3" do
    # TODO
    #    test "transfer a credit from a debit account to another debit account"
    #    test "transfer a credit from a credit account to another credit account"
    #    test "transfer a credit from a credit account to another debit account"
    #    test "transfer a credit from a debit account to another credit account"
  end

  describe "transfer" do
    # TODO : verify it supports transaction between different PIDS...
  end
end
