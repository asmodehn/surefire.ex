defmodule Blackjack.Game do
  @moduledoc """
    A Blackjack.Game implementation, using Surefire.

    To create players and run a quick game:

      iex> me = Blackjack.Player.new(:player_name)
      iex> bj = Blackjack.Game.new()
      iex> bj = bj |> Blackjack.Game.bet(me, 21)
      iex> bj = bj |> Blackjack.Game.play()
      iex> bj |> Blackjack.Game.resolve()

  And once more (TODO)

  """

  alias Blackjack.{Round, Card}
  alias Blackjack.Event.{PlayerExit}

  #    @derive {Inspect, only: [:players]}
  defstruct players: %{},
            rounds: []

  # TODO : map of games, to match games with avatars...

  # TODO : we should add the total house bank amount here...

  @doc """
    Register players for a new game.
  """
  def new(deck_number \\ 3) do
    shoe = Card.deck() |> List.duplicate(deck_number) |> List.flatten() |> Enum.shuffle()
    %__MODULE__{} |> new_round(shoe)
  end

  def new_round(%__MODULE__{rounds: games}, shoe) do
    %__MODULE__{
      rounds: [Round.new(shoe) | games]
    }
  end

  def continue_game(%__MODULE__{rounds: [last_round | previous_rounds]}) do
    %__MODULE__{
      rounds: [Round.new(last_round.shoe) | [last_round | previous_rounds]]
    }
  end

  def with_player(%__MODULE__{players: players} = game, player) do
    player_id = Surefire.Player.id(player)

    %{game | players: players |> Map.put(player_id, player)}
  end

  # semantics : open position... bet in the betting box
  # TODO : change this into interaction with avatar...
  def bet(
        %__MODULE__{players: players, rounds: [game | old_games]} = bj,
        player,
        amount
      )
      when is_number(amount) do
    player_id = Surefire.Player.id(player)

    players =
      if player_id not in Map.keys(players) do
        players |> Map.put(player_id, player)
      else
        players
      end

    avatar = Surefire.Player.avatar(player, game)

    #          {
    #    # TODO USEful avatar copy here, or get rid of it ??
    #      %{player | avatars: player.avatars |> Map.put(
    #                                                Surefire.Round.id(round), avatar
    #                                              )} ,
    #      avatar
    #    }

    #      {upd_player, avatar} = player |> Blackjack.Player.enter_round(game)

    %{
      bj
      | rounds: [game |> Round.bet(avatar, amount) | old_games],
        players: players
        #         players: players |> Map.replace(player_id, upd_player),
    }
  end

  def play(%__MODULE__{rounds: [game | old_games]} = bj) do
    played_game =
      game
      |> Round.deal()
      |> Round.play()

    %{bj | rounds: [played_game | old_games]}
  end

  @doc ~s"""
    Resolves the current game to the end.
    Modifies player's credits depending on game result.
  """

  def resolve(%__MODULE__{rounds: [game | old_games]} = bj) do
    {resolved_game, exits} = Round.resolve(game) |> IO.inspect()

    for %Blackjack.Event.PlayerExit{id: pp_id, gain: gain} <- exits,
        reduce: %{bj | rounds: [resolved_game | old_games]} do
      %__MODULE__{} = acc ->
        # TODO : with transactions / accounting instead...

        %{
          acc
          | players:
              acc.players
              |> Map.update!(pp_id, fn
                pp ->
                  # payers[pp_id] == pp
                  Surefire.Player.get(pp, gain)
              end)
        }
    end
  end
end
