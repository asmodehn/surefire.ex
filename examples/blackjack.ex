defmodule Blackjack do
  @moduledoc """
    A Blackjack implementation, using Surefire.

    To create players and run a quick game:

      iex> me = Blackjack.Player.Interactive.new()
      iex> bj = Blackjack.new([me])
      iex> bj = bj |> Blackjack.bet(sureFire.Player.id(me), 21)
      ies> bj = bj |> Blackjack.deal()

  """

  alias Blackjack.Table
  alias Blackjack.Event.{PlayerExit}

  #    @derive {Inspect, only: [:players]}
  defstruct players: %{},
            table: %Table{}

  # TODO : we should add the total house bank amount here...

  @doc """
    Register players for a new game.
  """
  def new(players) do
    %__MODULE__{
      players: players |> Enum.map(fn p -> {Surefire.Player.id(p), p} end) |> Enum.into(%{}),
      table: Table.new()
    }

    # TODO : loop by adding players via add_player/2
  end

  # TODO : new and bet are the same ? (blind bets -> start game ??)
  # semantics : open position... bet in the betting box
  def bet(%__MODULE__{table: table} = game, player, amount)
      when is_atom(player) and is_number(amount) do
    players =
      if player not in Map.keys(game.players) do
        # TODO : atom or not ???
        game.players ++ [player]
      else
        game.players
      end

    %{
      game
      | players: Map.update!(players, player, fn p -> p |> Surefire.Player.bet(amount) end),
        table: table |> Table.bet(player, amount)
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
    for p <- Map.keys(players), reduce: game do
      game ->
        if is_atom(table.positions[p].value) do
          # blackjack or bust: skip this... until resolve (???)
          # TODO : bust should exit the player from the game immediately (will not win in any case)
          # => can only become "spectator" (useful ??)
          game
        else
          %{game | table: table |> Table.maybe_card_to(game.players[p])}
          # ? TODO: recurse here or after whole loop ?
        end
    end

    # TODO : loop until the end of player turns

    # Resolve dealer after all players
    %{game | table: table |> Table.play(:dealer)}
  end

  @doc ~s"""
    To the end, where the dealer get cards until >17
  """

  def resolve(%__MODULE__{players: players, table: table} = bj) do
    for p <- Map.keys(players), reduce: bj do
      acc ->
        {updated_table, %PlayerExit{id: ^p, gain: gain}} = table |> Table.resolve(p)

        %{
          acc
          | table: updated_table,
            players:
              acc.players
              |> Map.update(p, 0, fn
                pp -> Blackjack.Player.event(pp, gain)
              end)
        }
    end
  end
end
