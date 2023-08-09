defmodule Blackjack.Player do
  defmodule PlayCommand do
    defstruct id: nil, command: :stand
  end

  defmodule GainEvent do
    defstruct id: nil, gain: 0
  end

  # Note: this is to enforce in design that Blackjack depends on Surefire,
  # But Surefire already has most of mandatory data for a game...
  # some extra data can be added if needed by the game however.
  defstruct sf: nil,
            extra_stuff: nil,
            # TMP new avatar implementation... WIP
            # TODO : map of avatars...
            avatars: Blackjack.Avatar.IEx

  # TODO : review whole design here...

  def new_interactive() do
    %__MODULE__{sf: Surefire.IExPlayer.new()}
  end

  def new_test(name, credits) do
    %__MODULE__{sf: Surefire.TestPlayer.new(name, credits)}
  end

  def event(%__MODULE__{} = player, gain) do
    %GainEvent{id: Surefire.Player.id(player.sf), gain: gain}
  end

  #  def hit_stand(%__MODULE__{} = player, hit_or_stand)
  #      when hit_or_stand in [:hit, :stand] do
  #    %PlayCommand{id: Surefire.Player.id(player.sf), command: hit_or_stand}
  #  end
  #
  #

  # TODO review dispatching on avatar here...
  def hit_or_stand(%__MODULE__{avatar: avatar} = player, player_hand, dealer_hand) do
    apply(avatar, :hit_or_stand, [player_hand, dealer_hand])
  end

  # TODO : automated (AI) player for multiplyer games...

  defimpl Surefire.Player do
    def id(player) do
      Surefire.Player.id(player.sf)
    end

    def name(player) do
      Surefire.Player.name(player.sf)
    end

    def credits(player) do
      Surefire.Player.credits(player.sf)
    end

    def bet(%Blackjack.Player{} = player, bet) do
      %Blackjack.Player{player | sf: Surefire.Player.bet(player.sf, bet)}
    end

    def get(%Blackjack.Player{} = player, gain) do
      %Blackjack.Player{player | sf: Surefire.Player.get(player.sf, gain)}
    end

    def avatar(%Blackjack.Player{} = player, game_id) do
    end
  end
end
