defmodule Surefire.Money do
  @moduledoc ~s"""
  A module representing a real world currency.

  Even if money transfers internally may not always represent real world currency movements
  IT should be possible to "eventually rejoin" with the state of the world.
  """

  # TODO : use Decimal
  # TODO: needs to be usable with Accounting module
  #       to make sure nothing is lost during compute
end
