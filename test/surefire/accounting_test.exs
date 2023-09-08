defmodule Surefire.AccountingTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting

  # childspec for logserver, passing a name,
  # to not conflict with application's logserver.
  @logserver_spec %{
    id: Accounting.LogServer,
    start: {Accounting.LogServer, :start_link, [[], [name: :logserver_in_accountingtest]]}
  }

  describe "ensure_history/1" do
    setup do
      with log_pid <- start_supervised!(@logserver_spec) do
        %{log_pid: log_pid}
      end
    end

    test "return the pid of an already started process with the proper name",
         %{log_pid: log_pid} do
      assert Accounting.ensure_history(:logserver_in_accountingtest) == {:ok, log_pid}
    end

    test "start another process with the proper name if needed",
         %{log_pid: log_pid} do
      {:ok, another_pid} = Accounting.ensure_history(:test_another_log)

      on_exit(fn ->
        assert not Process.alive?(another_pid)
      end)

      assert another_pid != log_pid
    end
  end

  describe "history/3" do
    setup do
      t =
        Accounting.Transaction.build("test description")
        |> Accounting.Transaction.with_debit(self(), :test_account_a, 42)
        |> Accounting.Transaction.with_credit(self(), :test_account_b, 42)

      assert Accounting.Transaction.verify_balanced(t)

      {:ok,
       %Accounting.History{
         transactions: committed
       } = history} = Accounting.History.commit(%Accounting.History{}, "transac_id", t)

      with log_pid <-
             start_supervised!(%{
               id: Accounting.LogServer,
               start:
                 {Accounting.LogServer, :start_link,
                  [history, [name: :logserver_in_accountingtest]]}
             }) do
        %{log_pid: log_pid}
      end
    end

    test "retrieve a chunk of history, between from and to transactions ids, included" do
      %Accounting.History.Chunk{
        from: "transac_id",
        until: "transac_id",
        transactions: transactions
      } = Accounting.history("transac_id", "transac_id", history: :logserver_in_accountingtest)

      %Accounting.Transaction{description: descr, debit: debits, credit: credits} =
        transactions["transac_id"]

      assert descr == "test description"

      # Note : using self as pid here sine the account was stored in transaction as coming from the test process...
      assert debits == %{self() => [test_account_a: 42]}
      assert credits == %{self() => [test_account_b: 42]}
    end
  end

  #
  #  describe "commit/1" do
  #      setup do
  #      with log_pid <- start_supervised!(@logserver_spec),
  #           testledger_pid <- start_supervised!(%{
  #            id: Test_LedgerServer,
  #            start: { Accounting.LedgerServer, :start_link, [log_pid, [name: :test_ledger]]                                                                                   }
  #           } ) ,
  #                secondledger_pid <- start_supervised!(%{
  #            id: Second_LedgerServer,
  #            start: { Accounting.LedgerServer, :start_link, [log_pid, [name: :second_ledger]]                                                                                   }
  #           } )                                       do
  #        %{log_pid: log_pid, testledger_pid: testledger_pid, secondledger_pid: secondledger_pid}
  #      end
  #    end
  #
  #
  #    test "refuses an empty transaction" do
  #      t = Accounting.transaction("test_unbalanced_transaction")
  #      assert_raise(FunctionClauseError, fn ->
  #          Accounting.commit(t, history: :logserver_in_accountingtest)
  #     end)
  #    end
  #
  #    test "refuses an unbalanced transaction", %{testledger_pid: testledger_pid} do
  #
  #      :ok = Surefire.Accounting.LedgerServer.open_account(testledger_pid, :alice, "alice account", :debit)
  #
  #      t = Accounting.transaction("test_unbalanced_transaction")
  #      |> Accounting.debit_from(
  #           %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice}, 42)
  #
  #    assert_raise(Accounting.LogServer.UnbalancedTransaction, fn ->
  #      Accounting.commit(t, history: :logserver_in_accountingtest)
  #    end)
  #      end
  #
  #    test "refuse a transaction with an unknown account",
  #         %{testledger_pid: testledger_pid} do
  #
  #      :ok = Surefire.Accounting.LedgerServer.open_account(testledger_pid, :alice, "alice account", :debit)
  #
  #      t = Accounting.transaction("test_unbalanced_transaction")
  #      |> Accounting.debit_from(
  #           %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice}, 42)
  #      |> Accounting.debit_to(
  #           %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :bob}, 42)
  #
  #    assert_raise(Accounting.LogServer.UnknownAccounts, fn ->
  #      Accounting.commit(t, history: :logserver_in_accountingtest)
  #    end)
  #      end
  #
  #    test "accept, balanced transaction between known accounts on same ledger",
  #       %{testledger_pid: testledger_pid} do
  #
  #      :ok = Surefire.Accounting.LedgerServer.open_account(testledger_pid, :alice, "alice account", :debit)
  #      :ok = Surefire.Accounting.LedgerServer.open_account(testledger_pid, :bob, "bob account", :debit)
  #
  #      t = Accounting.transaction("test_same_ledger_transaction")
  #      |> Accounting.debit_from(
  #           %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice}, 42)
  #      |> Accounting.debit_to(
  #           %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :bob}, 42)
  #
  #      tid = Accounting.commit(t, history: :logserver_in_accountingtest)
  #
  #      %Accounting.History.Chunk{transactions: retrieved} = Accounting.history(tid, tid, history: :logserver_in_accountingtest)
  #
  #      assert retrieved[tid].description == "test_same_ledger_transaction from alice to bob"
  #      assert retrieved[tid].debit == %{testledger_pid => [bob: 42]}
  #      assert retrieved[tid].credit == %{testledger_pid => [alice: 42]}
  #
  # end
  #
  # test "accept, balanced transaction between known accounts on different ledger",
  #       %{testledger_pid: testledger_pid, secondledger_pid: secondledger_pid} do
  #
  #      :ok = Surefire.Accounting.LedgerServer.open_account(testledger_pid, :alice, "alice account", :debit)
  #      :ok = Surefire.Accounting.LedgerServer.open_account(secondledger_pid, :bob, "bob account", :debit)
  #
  #      t = Accounting.transaction("test_diff_ledger_transaction")
  #      |> Accounting.debit_from(
  #           %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice}, 42)
  #      |> Accounting.debit_to(
  #           %Accounting.AccountID{ledger_pid: secondledger_pid, account_id: :bob}, 42)
  #
  #      tid = Accounting.commit(t, history: :logserver_in_accountingtest)
  #
  #      %Accounting.History.Chunk{transactions: retrieved} = Accounting.history(tid, tid, history: :logserver_in_accountingtest)
  #
  #      assert retrieved[tid].description == "test_diff_ledger_transaction from alice to bob"
  #      assert retrieved[tid].debit == %{secondledger_pid => [bob: 42]}
  #      assert retrieved[tid].credit == %{testledger_pid => [alice: 42]}
  #
  # end
  #
  #
  #
  #  end

  describe "balance/1" do
    setup do
      with log_pid <- start_supervised!(@logserver_spec),
           testledger_pid <-
             start_supervised!(%{
               id: Test_LedgerServer,
               start: {Accounting.LedgerServer, :start_link, [log_pid, [name: :test_ledger]]}
             }) do
        %{log_pid: log_pid, testledger_pid: testledger_pid}
      end
    end

    test "return the balance of a debit account correctly",
         %{testledger_pid: testledger_pid} do
      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :alice,
          "alice account",
          :debit
        )

      :ok =
        Surefire.Accounting.LedgerServer.open_account(testledger_pid, :bob, "bob account", :debit)

      t =
        Accounting.transaction("test_same_ledger_transaction")
        |> Accounting.debit_from(
          %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice},
          42
        )
        |> Accounting.debit_to(
          %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :bob},
          42
        )

      tid = Surefire.Accounting.LedgerServer.transfer(testledger_pid, t)

      assert Accounting.balance(%Accounting.AccountID{
               ledger_pid: testledger_pid,
               account_id: :alice
             }) == -42

      assert Accounting.balance(%Accounting.AccountID{
               ledger_pid: testledger_pid,
               account_id: :bob
             }) == 42
    end

    test "return the balance of a credit account correctly",
         %{testledger_pid: testledger_pid} do
      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :alice,
          "alice account",
          :credit
        )

      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :bob,
          "bob account",
          :credit
        )

      t =
        Accounting.transaction("test_same_ledger_transaction")
        |> Accounting.credit_from(
          %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice},
          42
        )
        |> Accounting.credit_to(
          %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :bob},
          42
        )

      tid = Surefire.Accounting.LedgerServer.transfer(testledger_pid, t)

      assert Accounting.balance(%Accounting.AccountID{
               ledger_pid: testledger_pid,
               account_id: :alice
             }) == -42

      assert Accounting.balance(%Accounting.AccountID{
               ledger_pid: testledger_pid,
               account_id: :bob
             }) == 42
    end
  end

  describe "open_debit/1" do
    setup do
      with log_pid <- start_supervised!(@logserver_spec),
           testledger_pid <-
             start_supervised!(%{
               id: Test_LedgerServer,
               start: {Accounting.LedgerServer, :start_link, [log_pid, [name: :test_ledger]]}
             }),
           secondledger_pid <-
             start_supervised!(%{
               id: Second_LedgerServer,
               start: {Accounting.LedgerServer, :start_link, [log_pid, [name: :second_ledger]]}
             }) do
        %{log_pid: log_pid, testledger_pid: testledger_pid, secondledger_pid: secondledger_pid}
      end
    end

    test "open a debit account with funds from another account on same ledger",
         %{testledger_pid: testledger_pid} do
      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :original,
          "original account",
          :debit
        )

      alice_aid = %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice}
      original_aid = %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :original}

      Accounting.open_debit(alice_aid,
        from: original_aid,
        amount: 42
      )

      assert Accounting.balance(original_aid) == -42
      assert Accounting.balance(alice_aid) == 42
    end

    @tag :current
    test "opens a debit account with funds from another account on another ledger",
         %{log_pid: log_pid, testledger_pid: testledger_pid, secondledger_pid: secondledger_pid} do
      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :original,
          "original account",
          :debit
        )

      alice_aid = %Accounting.AccountID{ledger_pid: secondledger_pid, account_id: :alice}

      original_aid =
        %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :original}
        |> IO.inspect()

      Accounting.open_debit(alice_aid,
        from: original_aid,
        amount: 42
      )

      assert Accounting.balance(original_aid) == -42
      assert Accounting.balance(alice_aid) == 42
    end

    test "open a credit account with funds from another accout on same ledger",
         %{testledger_pid: testledger_pid} do
      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :original,
          "original account",
          :credit
        )

      alice_aid = %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :alice}
      original_aid = %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :original}

      Accounting.open_credit(alice_aid,
        from: original_aid,
        amount: 42
      )

      assert Accounting.balance(original_aid) == -42
      assert Accounting.balance(alice_aid) == 42
    end

    test "open a credit account with funds from another account on different ledger",
         %{testledger_pid: testledger_pid, secondledger_pid: secondledger_pid} do
      :ok =
        Surefire.Accounting.LedgerServer.open_account(
          testledger_pid,
          :original,
          "original account",
          :credit
        )

      alice_aid = %Accounting.AccountID{ledger_pid: secondledger_pid, account_id: :alice}
      original_aid = %Accounting.AccountID{ledger_pid: testledger_pid, account_id: :original}

      Accounting.open_credit(alice_aid,
        from: original_aid,
        amount: 42
      )

      assert Accounting.balance(original_aid) == -42
      assert Accounting.balance(alice_aid) == 42
    end
  end

  # TODO : test open_debit open_credit and close...

  #  setup do
  #    with player <- Surefire.TestPlayer.new(:test_player, 1000),
  #         game <- Surefire.TestGame.new() do
  #
  #
  #
  #         end
  #
  #  end
  #
  #  test "build debit transaction from player to avatar" do
  #
  #  end
  #
  #
  #  test "build debit transaction from avatar to game account" do
  #
  #  end
  #
  #
  #
  #  test "build debit transaction from game to round" do
  #
  #
  #  end
  #
  #
  #  test "build debit transaction from round to avatar" do
  #
  #  end
end
