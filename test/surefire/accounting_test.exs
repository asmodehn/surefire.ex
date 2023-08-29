defmodule Surefire.AccountingTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting

  describe "start_link/1" do
    test "starts the Accounting server" do
      {:ok, pid} = Accounting.start_link()

      assert Process.alive?(pid)
    end
  end

  describe "transfer/4" do
    setup do
      {:ok, pid} = Accounting.start_link()

      %{accounting_srv: pid}
    end

    test "records the transaction in the Accounting server history",
         %{accounting_srv: accounting_srv} do
      tid = Accounting.transfer(:alice, :bob, 42, accounting_srv)

      # TODO : test date, once the date function is exposed in history server...
      %Surefire.Accounting.Transaction{
        description: description,
        debit: debits,
        credit: credits
      } = Accounting.transactions(accounting_srv).transactions[tid]

      assert description == "Transfer 42 from alice to bob"
      assert debits == [alice: 42]
      assert credits == [bob: 42]
    end
  end

  describe "transactions/2" do
    setup do
      {:ok, pid} = Accounting.start_link()

      %{accounting_srv: pid}
    end

    test "retrieves partial history from the accounting Server history",
         %{accounting_srv: accounting_srv} do
      t1id = Accounting.transfer(:alice, :bob, 42, accounting_srv)
      t2id = Accounting.transfer(:bob, :charlie, 33, accounting_srv)
      t3id = Accounting.transfer(:alice, :charlie, 51, accounting_srv)

      retrieved = accounting_srv |> Accounting.transactions(since: t2id)

      assert retrieved.transactions[t1id] == nil

      %Accounting.Transaction{
        description: t2_descr,
        debit: t2_debits,
        credit: t2_credits
      } = retrieved.transactions[t2id]

      assert t2_descr == "Transfer 33 from bob to charlie"
      assert t2_debits == [bob: 33]
      assert t2_credits == [charlie: 33]

      %Accounting.Transaction{
        description: t3_descr,
        debit: t3_debits,
        credit: t3_credits
      } = retrieved.transactions[t3id]

      assert t3_descr == "Transfer 51 from alice to charlie"
      assert t3_debits == [alice: 51]
      assert t3_credits == [charlie: 51]
    end
  end
end
