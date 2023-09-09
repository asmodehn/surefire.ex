defmodule Surefire.Accounting do
  @moduledoc ~s"""
  Accounting API for Surefire Players and Games.

  Functions in this module represent different types of transactions, that needs to be:
  - created
  - recorded in history
  - represented (cached) in ledger accounts entries
  other functions to retrieve account balances, and deduce possible actions...

  """

  alias Surefire.Accounting.{History, Transaction, Account, LogServer, LedgerServer}

  # TODO : interface to create ( record and view transactions),
  # by relying on:
  #   - log server,
  #   - multiple ledger serverS
  #   - a chart of accounts to help validate transactions upon commit.

  # TODO later : real account / fake accounts with same interface...

  # TODO DESIGN IDEA : identifiers in processes :
  # - pid + account_id

  # API relying on "remote ids" (i.e. id in another process)

  @default_logserver_name LogServer

  defmodule AccountID do
    defstruct ledger_pid: nil, account_id: nil
  end

  def ensure_history(log_server_name \\ @default_logserver_name)
      when is_atom(log_server_name) do
    log_pid = Process.whereis(log_server_name)

    if log_pid == nil do
      LogServer.start_link(History.new(), name: log_server_name)
    else
      {:ok, log_pid}
    end
  end

  def transaction(descr_prefix) do
    Transaction.build(descr_prefix)
  end

  def debit_from(%Transaction{} = t, %AccountID{} = account_id, amount) do
    %{t | description: t.description <> " from #{account_id.account_id}"}
    |> Transaction.with_credit(account_id.ledger_pid, account_id.account_id, amount)
  end

  def debit_to(%Transaction{} = t, %AccountID{} = account_id, amount) do
    %{t | description: t.description <> " to #{account_id.account_id}"}
    |> Transaction.with_debit(account_id.ledger_pid, account_id.account_id, amount)
  end

  def credit_from(%Transaction{} = t, %AccountID{} = account_id, amount) do
    %{t | description: t.description <> " from #{account_id.account_id}"}
    |> Transaction.with_debit(account_id.ledger_pid, account_id.account_id, amount)
  end

  def credit_to(%Transaction{} = t, %AccountID{} = account_id, amount) do
    %{t | description: t.description <> " to #{account_id.account_id}"}
    |> Transaction.with_credit(account_id.ledger_pid, account_id.account_id, amount)
  end

  # maybe this is too brittle -> commit via a ledger server instead...
  #  def commit(%Transaction{} = t, opts \\ []) do
  #    hist_name = Keyword.get(opts, :history, @default_logserver_name)
  #    {:ok, log_pid} = ensure_history(hist_name)
  #    Surefire.Accounting.LogServer.commit(log_pid, t)
  #  end

  def history(from_tid, to_tid, opts \\ []) do
    hist_name = Keyword.get(opts, :history, @default_logserver_name)
    {:ok, log_pid} = ensure_history(hist_name)

    Surefire.Accounting.LogServer.chunk(log_pid, from: from_tid, to: to_tid)
  end

  @doc ~s"""
  Checking account entries during blackjack game:

      iex> me = Surefire.IExPlayer.new(:mememe, 100)
      iex> {av, me} = me |> Surefire.IExPlayer.avatar("bj_avatar", 50)
      iex> g = Blackjack.Round.new("demo round", Blackjack.Card.deck() |> Enum.shuffle())
      iex> g = g |> Blackjack.Round.enter(av)

      iex> Surefire.Accounting.audit(Surefire.Player.assets(me))

      iex> g = g |> Blackjack.Round.deal()
      iex> g = g |> Blackjack.Round.play()
      iex> g = g |> Blackjack.Round.resolve()

      iex> Surefire.Accounting.audit(Surefire.Player.assets(me))

  """
  def audit(%AccountID{} = account_id) do
    %Account{entries: entries} =
      Surefire.Accounting.LedgerServer.view(account_id.ledger_pid, account_id.account_id)

    TableRex.quick_render!(
      entries
      |> Enum.map(fn
        %Transaction.Entry{date: date, description: descr, debit: debit, credit: credit} ->
          [date, descr, debit, credit]
      end),
      ["date", "description", "debit", "credit"]
    )
    |> IO.puts()
  end

  def balance(%AccountID{} = account_id) do
    LedgerServer.view(account_id.ledger_pid, account_id.account_id)
    |> Surefire.Accounting.Account.balance()
  end

  def open_debit(%AccountID{ledger_pid: ledger_pid, account_id: id} = to,
        from: %AccountID{} = from,
        amount: amount
      ) do
    :ok = LedgerServer.open_account(ledger_pid, id, "#{id} Account", :debit)

    _tid =
      if from.ledger_pid == ledger_pid do
        LedgerServer.transfer_debit(
          ledger_pid,
          "Opening Debit account #{id}",
          from.account_id,
          id,
          amount
        )
      else
        t =
          transaction("Opening Debit account #{id}")
          |> debit_from(from, amount)
          |> debit_to(to, amount)

        # Note: we arbitrarily chose one ledger server to access its history (only one for now)
        LedgerServer.transfer(ledger_pid, t)
      end
  end

  def open_credit(%AccountID{ledger_pid: ledger_pid, account_id: id} = to,
        from: %AccountID{} = from,
        amount: amount
      ) do
    :ok = LedgerServer.open_account(ledger_pid, id, "#{id} Account", :credit)

    _tid =
      if from.ledger_pid == ledger_pid do
        LedgerServer.transfer_credit(
          ledger_pid,
          "Opening Credit account #{id}",
          from.account_id,
          id,
          amount
        )
      else
        t =
          transaction("Opening Credit account #{id}")
          |> credit_from(from, amount)
          |> credit_to(to, amount)

        # Note: we arbitrarily chose one ledger server to access its history (only one for now)
        LedgerServer.transfer(ledger_pid, t)
      end
  end

  def close(%AccountID{ledger_pid: ledger_pid, account_id: id}) do
    :ok = LedgerServer.close_account(ledger_pid, id)

    # TODO : calculate closing balance... (maybe inside account itself on callback ??)
  end
end
