defmodule Blackjack.Player.Random do
  defmodule PlayCommand do
    defstruct id: nil, command: :stand
  end

  defmodule GainEvent do
    defstruct id: nil, gain: 0
  end

  # TODO : isnt the id implicit here (ie. from context : iex, node, etc...)
  defstruct id: nil,
            # TODO : specific struct, keeping count of P n L, only for managing money...
            account: 0,
            avatars: %{}

  def new(id, amount \\ 0) do
    %__MODULE__{id: id, account: amount}
  end

  #  def enter_round(player, round) do
  #    interactive = Keyword.get(opts, :interactive, false)
  #
  #    avatar = if interactive do
  #      # TODO : avatar_id = player_id-round_id-incr
  #      Blackjack.Avatar.IEx.new(player.id)
  #    else
  #      Blackjack.Avatar.Random.new(player.id)
  #    end
  #
  #    {
  #    # TODO USEful avatar copy here, or get rid of it ??
  #      %{player | avatars: player.avatars |> Map.put(
  #                                                Surefire.Round.id(round), avatar
  #                                              )} ,
  #      avatar
  #    }
  #  end

  #  def new_interactive(round) do
  #    Blackjack.Avatar.IEx.new()
  #  end
  #
  #  def new_test(name, credits) do
  #    %__MODULE__{sf: Surefire.TestPlayer.new(name, credits)}
  #  end

  def event(%__MODULE__{} = player, gain) do
    %GainEvent{id: player.id, gain: gain}
  end

  #  def hit_stand(%__MODULE__{} = player, hit_or_stand)
  #      when hit_or_stand in [:hit, :stand] do
  #    %PlayCommand{id: Surefire.Player.id(player.sf), command: hit_or_stand}
  #  end
  #
  #

  #  # TODO review dispatching on avatar here...
  #  def hit_or_stand(%__MODULE__{avatars: avatar} = player, player_hand, dealer_hand) do
  #    apply(avatar, :hit_or_stand, [player_hand, dealer_hand])
  #  end

  # TODO : automated (AI) player for multiplayer games...
  #
  defimpl Surefire.Player do
    def id(player) do
      player.id
    end

    #
    #    def name(player) do
    #      Surefire.Player.name(player.sf)
    #    end
    #
    #    def credits(player) do
    #      Surefire.Player.credits(player.sf)
    #    end
    #
    #    def bet(%Blackjack.Player{} = player, bet) do
    #      %Blackjack.Player{player | sf: Surefire.Player.bet(player.sf, bet)}
    #    end
    #

    def avatar(player, round) do
      Blackjack.Avatar.Random.new(player.id |> String.to_atom(), player.id)
    end

    def get(%Blackjack.Player.Random{} = player, gain) do
      %Blackjack.Player.Random{player | account: player.account + gain}
    end

    #
    #    def avatar(%Blackjack.Player{} = player, game_id) do
    #    end
  end
end

defmodule Blackjack.Player.IEx do
  # TODO : isnt the id implicit here (ie. from context : iex, node, etc...)
  defstruct id: nil,
            # TODO : specific struct, keeping count of P n L, only for managing money...
            account: 0,
            avatars: %{}

  def new(id, amount \\ 0) do
    %__MODULE__{id: id, account: amount}
  end

  defimpl Surefire.Player do
    def id(player) do
      player.id
    end

    #
    #    def name(player) do
    #      Surefire.Player.name(player.sf)
    #    end
    #
    #    def credits(player) do
    #      Surefire.Player.credits(player.sf)
    #    end
    #

    def avatar(player, round) do
      # TODO : avatar_id = player_id-round_id-incr
      Blackjack.Avatar.IEx.new(player.id |> String.to_atom(), player.id)
    end

    #    def bet(%Blackjack.Player{} = player, bet) do
    #      %Blackjack.Player{player | sf: Surefire.Player.bet(player.sf, bet)}
    #    end
    #
    def get(%Blackjack.Player.IEx{} = player, gain) do
      %Blackjack.Player.IEx{player | account: player.account + gain}
    end

    #
    #    def avatar(%Blackjack.Player{} = player, game_id) do
    #    end
  end
end
