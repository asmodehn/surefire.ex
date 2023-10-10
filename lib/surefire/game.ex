defprotocol Surefire.Game do
  @moduledoc ~s"""
  Round protocol to allow a Game to manipulate any rounds in the same way.
  """

  @type t :: any()

  @spec id(t) :: atom()
  def id(round)

  @spec enter(t, Surefire.Avatar.t()) :: t
  def enter(round, avatar)

  # TODO : return wins/losses
  @spec play(t) :: any
  def play(round)
end

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
