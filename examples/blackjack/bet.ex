defmodule Blackjack.Bet do

  # TODO : track  (Surefire) bet amount AND optionally transaction ID...

  # The interface to bets map from surefire ?

  # TODO : Betbox : bet linked with one or more game event.
  # Note  the association with a player is done outside of this module...
  #  => surefire's lib ??

  defstruct event: nil, amount: 0

# NEW
def new(game_event, amount) do
  %__MODULE__{
  event: game_event,
  amount: amount
  }
end

def update(%__MODULE__{} = bet, game_event) do
  # TODO: update bate based on game event
  case bet.event do
    # TODO review events after restructuration
    # Note: these correspond to a "current player" being checked by the code (cf surefire lib)
    ^game_event -> %{ bet | amount: bet.amount * 2}
    _other -> %{bet | amount: 0}
  end
end

defimpl Surefire.GameEventHandler do

  def process(%Blackjack.Bet{} = handler, event) do
    Blackjack.Bet.update(handler, event)
  end

end


#  # OLD
#  def stake(bet_map, game_event, avatar_id, amount) do
#    Surefire.Bets.stake(bet_map, game_event, avatar_id, amount)
#  end


          # TODO : test on this after structure decided : verify behavior on empty bet list for a player
          # => should NOT update to empty list -> not add non-existing player in map...
          def on( bet_map, player, game_event) do
  {_current, updated} = bet_map
              |> Map.get_and_update(player, fn
                bet_list when is_list(bet_list)
                -> {bet_list,
                  bet_list |> Enum.map(&Surefire.GameEventHandler.process(&1, game_event))}
              end)
updated
#                |> Surefire.Bets.winnings(
#                  player,
#                  fn
#                    s -> %{s | amount: s.amount * 2}
#                  end,
#                  # To not lose stake of yet unparsed player result
#                  fn s -> s end
#                )
end


#
#def on(bet_map, player, :lose) do
#  {_current, updated} = bet_map
#              |> Map.get_and_update(player, fn
#                bet_list when is_list(bet_list)
#                -> {bet_list,
#                               bet_list |> Enum.map(&Surefire.GameEventHandler.process(&1, :lose))
#                   }
#                               end)
#  updated

#  |> Surefire.Bets.winnings(
#                  player,
#                  fn
#                    s -> %{s | amount: s.amount * 0}
#                  end,
#
#                  # To keep other players' result
#                  fn s -> s end
#                )
#            end













end
