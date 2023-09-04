defprotocol Surefire.Game do
  @moduledoc ~s"""
    This module describe the common interface, mandatory for any and all games.
    This interface is aimed to be easily embedded in a Process, to keep state isolated.

    Therefore, Surefire also provide a Module defining this process for convenience
  """

  def new(game)
  def enter(game, player)

  def play(game)
  # Note play can be complex.
  # If problem -> crash -> every player is refunded.
end


defmodule Surefire.TestGame do

end

defmodule Surefire.IExGame do

    alias Surefire.Accounting.LedgerServer




end


  # Note : there are mutliple players in a game.
  # To be able to easily do:
  # updated_game = for p <- players, reduce: game do
  #     game -> update(game, p)
  # end
  #
  # We need a game/player model that "implicitly" reduce...
  # - get inspirations from CRDTs ??
  # - design an "inner module" only for reduceable player actions ?
  # - other solution ??
  # CAREFUL : the way these reduce ARE part of the game rules
  #
  # => make game a collectable ??
  # Note : if we keep track of all actions, we can make it an enumerable as well ?? -> allows replays
