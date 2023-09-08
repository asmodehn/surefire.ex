# defprotocol Surefire.Game do
#  @moduledoc ~s"""
#  Round protocol to allow a Game to manipulate any rounds in the same way.
#  """
#
#  def id(round)
#
#  def enter(round, avatar)
#
#  def play(round)
#
# end
#
#
# defmodule Surefire.TestGame do
#
#  defstruct id: nil
#
#
#  def new(id) do
#    %__MODULE__{id: id}
#  end
#
#
#  def turn(%__MODULE__{} = game, avatar) do
#
#    # propose opportunities to avatar
#    # avatar bet on some opportunities
#    # random roll / game decision
#    # potential payback
#
#    # loop...
#
#  end
#
#
#  defimpl Surefire.Game do
#
#    def id(game) do
#      game.id
#    end
#
#    def enter(game, avatar) do
#
#
#
#
#    end
#
#    def play(game) do
#
#    end
#
#
#  end
#
# end
