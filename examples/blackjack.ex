defmodule Blackjack do
  @moduledoc """
    A Blackjack implementation, using Surefire.

    To create players and run a quick game:

      iex> me = Blackjack.Player.Interactive.new()
      iex> bj = Blackjack.new([me])
      iex> bj = bj |> Blackjack.bet(sureFire.Player.id(me), 21)
      ies> bj = bj |> Blackjack.deal()

  """

  import Blackjack.Deck, only: [deck: 0]

  alias Blackjack.{Bets, Table, Hand}

  #    @derive {Inspect, only: [:players]}
  defstruct players: %{},
            # TODO : shouldnt bets be on the table ??
            bets: %Bets{},
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

  def bet(%__MODULE__{bets: bets} = game, player, amount)
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
        bets: bets |> Bets.player_bet(player, amount)
    }
  end

  @doc ~s"""
    Only take in the game players who have already bet something...
  other player stay in game, but don't receive cards and cannot play.
  """
  def deal(%__MODULE__{bets: bets} = game) do
    players = Bets.players(bets)

    table = Table.deal(game.table, players)

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

  def resolve(%__MODULE__{players: players, table: table} = bj)
      when is_atom(table.dealer.value) do
    case table.dealer.value do
      :bust ->
        for p <- Map.keys(players), reduce: bj do
          acc ->
            {player_bet, bets} = acc.bets |> Bets.player_end(p)

            %{
              acc
              | bets: bets,
                table: table |> Table.close_position(p),
                players:
                  acc.players
                  |> Map.update(p, 0, fn
                    pp -> Blackjack.Player.event(pp, player_bet * 2)
                  end)
            }
        end

      :blackjack ->
        for p <- Map.keys(players), reduce: bj do
          # TODO : this depends on player's hand value ...
          acc ->
            {_player_bet, bets} = acc.bets |> Bets.player_end(p)
            %{acc | bets: bets, table: table |> Table.close_position(p)}
        end
    end
  end

  def resolve(%__MODULE__{players: players, table: table} = bj)
      when is_integer(table.dealer.value) do
    for p <- Map.keys(players), reduce: bj do
      bj ->
        {table, %Blackjack.Event.PlayerExit{id: ^p, gain: gain}} = bj.table |> Table.resolve(p)
        {player_bet, bets} = bj.bets |> Bets.player_end(p)

        players =
          if gain do
            bj.players
            |> Map.update(p, 0, fn pp -> Blackjack.Player.event(pp, player_bet * 2) end)
          else
            bj.players
          end

        %{bj | table: table, bets: bets, players: players}
    end
  end
end
