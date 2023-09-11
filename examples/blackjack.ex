defmodule Blackjack do
  @moduledoc ~s"""
  This module defines the interface for a blackjack game,
  as an example of surefire capabilities.
  """

  # TODO : Surefire behaviour to allow unsupervised game creation by the lib itself.

  #  @behaviour

  # TODO : number of decks as hyperparameters somewhere...
  def new_game(id, rand_seed, %Surefire.Accounting.AccountID{} = account_id \\ nil) do
    # Note : nil as account -> "fake" game without proper transactions
    Blackjack.Round.new(id, Card.deck() |> Enum.shuffle(), account_id)
  end
end
