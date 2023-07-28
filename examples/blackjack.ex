defmodule Blackjack do
  @moduledoc """
    A Blackjack implementation, using Surefire.

    To create players and run a quick game:

      iex> me = Blackjack.Player.new_interactive()
      iex> bj = Blackjack.new()
      iex> bj = bj |> Blackjack.bet(me, 21)
      iex> bj = bj |> Blackjack.deal()
      iex> bj = bj |> Blackjack.play()
      iex> bj = bj |> Blackjack.resolve()

  """

  alias Blackjack.Table
  alias Blackjack.Event.{PlayerExit}

  #    @derive {Inspect, only: [:players]}
  defstruct players: %{},
            table: %Table{}

  # TODO : rounds: []

  # TODO : we should add the total house bank amount here...

  @doc """
    Register players for a new game.
  """
  def new() do
    %__MODULE__{
      table: Table.new()
    }
  end

  # TODO: new round

  # TODO : new and bet are the same ? (blind bets -> start game ??)
  # semantics : open position... bet in the betting box
  def bet(%__MODULE__{table: table} = game, %Blackjack.Player{} = player, amount)
      when is_number(amount) do
    player_id = Surefire.Player.id(player)

    players =
      if player_id not in Map.keys(game.players) do
        game.players |> Map.merge(Map.new([{player_id, player}]))
      else
        game.players
      end

    %{
      game
      | players: Map.update!(players, player_id, fn p -> p |> Surefire.Player.bet(amount) end),
        table: table |> Table.bet(player_id, amount)
    }
  end

  @doc ~s"""
    Only take in the game players who have already bet something...
  other player stay in game, but don't receive cards and cannot play.
  """
  def deal(%__MODULE__{} = game) do
    table = Table.deal(game.table)

    %{game | table: table}
  end

  @doc ~s"""
    The play phase, where each player makes decisions, and cards are dealt
  """
  def play(%__MODULE__{players: players, table: table} = game) do
    # TODO: make sure somehow that all players who did bet have a hand.
    played_game =
      for p <- Map.keys(players), reduce: game do
        game ->
          IO.inspect("#{p} turn...")

          %{
            game
            | table:
                table
                |> Table.play(
                  p,
                  &Blackjack.Player.hit_or_stand(game.players[p], &1)
                )
          }
      end
  end

  @doc ~s"""
    To the end, where the dealer get cards until >17
  """

  def resolve(%__MODULE__{players: players, table: table} = bj) do
    # Resolve dealer (after all players have played)
    resolved_game = %{bj | table: table |> Table.play(:dealer)}

    # Manipulate player bets and positions...
    for p <- Map.keys(players), reduce: resolved_game do
      acc ->
        {updated_table, %PlayerExit{id: ^p, gain: gain}} = resolved_game.table |> Table.resolve(p)

        %{
          acc
          | table: updated_table,
            players:
              acc.players
              |> Map.update!(p, fn
                pp ->
                  %Blackjack.Player.GainEvent{id: pp_id, gain: gain} =
                    Blackjack.Player.event(pp, gain)

                  # payers[pp_id] == pp
                  Surefire.Player.get(players[pp_id], gain)
              end)
        }
    end
  end
end
