defmodule Blackjack.Bets do
  # TODO : maybe "positions" is more accurate / useful ?
  # Note: one position can have multiple hands (on split ! -> equal bet)
  # Also one player can play multiple positions...
  defstruct bets: []

  # Note: bets seems to be like monad : a state embedded deep inside a process...
  # Maybe there is a way to leverage that for better design ?
  # Note : we want to track each bet (opening positions) separately, in event sourcing style
  #  => teh current bet amount is an aggregate(?)/collectable(?) view of a set of betting events

  # TODO : instead of one integer, a list of int
  #        that are summable to give the current value (accounting-like -> store events, not state)

  def player_bet(%__MODULE__{} = b, player, bet) do
    %{b | bets: Keyword.update(b.bets, player, bet, fn v -> v + bet end)}
  end

  def player_end(%__MODULE__{} = b, player) do
    {player_bet, bets} = Keyword.pop!(b.bets, player)
    {player_bet, %{b | bets: bets}}
  end

  def players(%__MODULE__{bets: b}) do
    Keyword.keys(b)
  end
end
