defmodule Surefire.Accounting do
  @moduledoc ~s"""
  Accounting API for Surefire Players and Games.

  Functions in this module represent different types of transactions, that needs to be:
  - created
  - recorded in history
  - represented (cached) in ledger accounts entries
  other functions to retrieve account balances, and deduce possible actions...

  """

  alias Surefire.Accounting.{History, Transaction}

  # TODO : interface to create ( record and view transactions),
  # by relying on:
  #   - log server,
  #   - multiple ledger serverS
  #   - a chart of accounts to help validate transactions upon commit.
end
