defmodule Surefire.LedgerServerTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.{LedgerServer, LogServer, Account, Transaction}

  describe "start_link/1" do
    setup do
      history_pid = start_supervised!(LogServer)

      %{history_pid: history_pid}
    end

    test "starts the Ledger server", %{history_pid: history_pid} do
      {:ok, pid} = LedgerServer.start_link(history_pid)

      assert Process.alive?(pid)
    end
  end

  describe "open_account/3" do
    setup do
      with history_pid <- start_supervised!(LogServer),
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
      with history_pid <- start_supervised!(LogServer),
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
      with history_pid <- start_supervised!(LogServer),
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

      tid = LedgerServer.transfer(bizserver_pid, :test_debit_A, :test_debit_B, 42)

      %Account{
        id: :test_debit_A,
        name: "Test Debit Account A",
        type: :debit,
        entries: entries_A,
        balance: %Surefire.Accounting.Account.Balance{debits: 42, credits: 0}
      } = LedgerServer.view(bizserver_pid, :test_debit_A)

      # pattern matching for partial match (because of date !)
      [
        %Transaction.Entry{
          transaction_id: ^tid,
          account: :test_debit_A,
          description: "Transfer 42 from test_debit_A to test_debit_B",
          debit: 42,
          credit: 0
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
          description: "Transfer 42 from test_debit_A to test_debit_B",
          debit: 0,
          credit: 42
        }
      ] = entries_B
    end
  end

  describe "balance/2" do
    setup do
      with history_pid <- start_supervised!(LogServer),
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

      _tid = LedgerServer.transfer(bizserver_pid, :test_debit_A, :test_debit_B, 42)

      assert LedgerServer.balance(bizserver_pid, :test_debit_A) == 42

      assert LedgerServer.balance(bizserver_pid, :test_debit_B) == -42
    end
  end

  # TODO : find a way to use ONE account or N accounts in a ledger in the same way...
end
