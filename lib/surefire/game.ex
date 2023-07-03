defprotocol Surefire.Game do

  @moduledoc ~s"""
    This module describe the rules of the game.
    Specifically what gains are associated with which events.

    Also, this defines an interface that can be easily embedded in a Process, to keep state isolated.
    Therefore, Surefire also provide a Module defining this process for convenience
  """


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

  def into(game, rules)




end




