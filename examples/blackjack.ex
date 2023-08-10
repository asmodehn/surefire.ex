defmodule Blackjack do
  @moduledoc """
    A Blackjack implementation, using Surefire.

    To create players and run a quick game:

      iex> me = Blackjack.Player.new_interactive()
      iex> bj = Blackjack.new()
      iex> bj = bj |> Blackjack.bet(me, 21)
      iex> bj = bj |> Blackjack.play()
      iex> bj |> Blackjack.resolve()

  """

  alias Blackjack.Round
  alias Blackjack.Event.{PlayerExit}

  #    @derive {Inspect, only: [:players]}
  defstruct players: %{},
            rounds: []

  # TODO : map of games, to match games with avatars...

  # TODO : we should add the total house bank amount here...

  @doc """
    Register players for a new game.
  """
  def new() do
    %__MODULE__{} |> new_game()
  end

  def new_game(%__MODULE__{rounds: games}) do
    %__MODULE__{
      rounds: [Round.new() | games]
    }
  end

  # TODO : new and bet are the same ? (blind bets -> start game ??)
  # semantics : open position... bet in the betting box
  def bet(
        %__MODULE__{players: players, rounds: [game | old_games]} = bj,
        %Blackjack.Player{} = player,
        amount
      )
      when is_number(amount) do
    player_id = Surefire.Player.id(player)

    players =
      if player_id not in Map.keys(players) do
        players |> Map.merge(Map.new([{player_id, player}]))
      else
        players
      end

    %{
      bj
      | players: Map.update!(players, player_id, fn p -> p |> Surefire.Player.bet(amount) end),
        rounds: [game |> Round.bet(player_id, amount) | old_games]
    }
  end

  def play(%__MODULE__{players: players, rounds: [game | old_games]} = bj) do
    player_call = fn ph, dh -> Blackjack.Player.hit_or_stand(ph, dh) end

    played_game =
      game
      |> Round.deal()
      |> Round.play(player_call)

    %{bj | rounds: [played_game | old_games]}
  end

  @doc ~s"""
    Resolves the current game to the end.
    Modifies player's credits depending on game result.
  """

  def resolve(%__MODULE__{rounds: [game | old_games]} = bj) do
    {resolved_game, exits} = Round.resolve(game)

    for %Blackjack.Event.PlayerExit{id: pp_id, gain: gain} <- exits,
        reduce: %{bj | rounds: [resolved_game | old_games]} do
      %__MODULE__{} = acc ->
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
