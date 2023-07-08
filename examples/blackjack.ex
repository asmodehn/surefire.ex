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
          game
        else
          %{game | table: table |> Table.maybe_card_to(game.players[p])}
          # ? TODO: recurse here or after whole loop ?
        end
    end

    # TODO : loop until the end of player turns
  end

  @doc ~s"""
    To the end, where the dealer get cards until >17
  """

  def resolve(%__MODULE__{players: players, table: table} = bj)
      when is_atom(table.dealer.value) do
    case table.dealer.value do
      :bust ->
        for p <- Map.keys(players), reduce: bj do
          acc -> player_win(acc, p)
        end

      :blackjack ->
        for p <- Map.keys(players), reduce: bj do
          acc -> player_lose(acc, p)
        end
    end
  end

  def resolve(%__MODULE__{players: players, table: table} = bj)
      when is_integer(table.dealer.value) do
    cond do
      # TODO : this is a (mandatory) dealer decision -> somewhere else or not ?
      # hit !
      table.dealer.value < 17 ->
        %{bj | table: bj.table |> Table.next_card() |> Table.card_to(:dealer)} |> resolve()

      # stand
      true ->
        for p <- Map.keys(players), reduce: bj do
          bj ->
            # TODO : handle "push" when both are equal...
            hand_comp = Hand.compare(bj.table.positions[p], bj.table.dealer)
            # TODO : review actual cases (with tests) here
            if hand_comp == :gt do
              player_win(bj, p)
            else
              player_lose(bj, p)
            end
        end
    end
  end

  def player_win(%__MODULE__{players: players, table: table} = game, player)
      when is_atom(player) do
    {player_bet, bets} = game.bets |> Bets.player_end(player)

    %{
      game
      | players:
          players |> Map.update(player, 0, fn p -> Blackjack.Player.event(p, player_bet * 2) end),
        bets: bets,
        table: table |> Table.close_position(player)
    }
  end

  def player_lose(%__MODULE__{table: table} = game, player) when is_atom(player) do
    {_player_bet, bets} = game.bets |> Bets.player_end(player)
    %{game | bets: bets, table: table |> Table.close_position(player)}
  end
end
