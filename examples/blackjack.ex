defmodule Blackjack.Bets do
  # TODO : maybe "positions" is more accurate / useful ?
  # TODO: check how we split money & player for various the positions / hands ...
  defstruct bets: []

  # Note: bets seems to be like monad : a state embedded deep inside a process...
  # Maybe there is a way to leverage that for better design ?
  # Note : we want to track each bet (opening positions) separately, in event sourcing style
  #  => teh current bet amount is an aggregate(?)/collectable(?) view of a set of betting events

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

defmodule Blackjack do
  @moduledoc """
    A Blackjack implementation, using Surefire.

    To create players and run a quick game:

      iex> me = Blackjack.Player.Interactive.new()
      iex> bj = Blackjack.new([me])
      iex> bj = bj |> Blackjack.bet(sureFire.Player.id(me), 21)
      ies> bj = bj |> Blackjack.deal()

  """

  alias Blackjack.{Bets, Table}

  #  @derive {Inspect, only: [:bets, :table]}
  defstruct players: %{},
            bets: %Bets{},
            table: %Table{}

  #            state: nil
  #
  #  use Fsmx.Struct, fsm: Blackjack.Rules

  @doc """
    Register players for a new game.
  """
  def new(players) do
    %__MODULE__{
      players: players |> Enum.map(fn p -> {Surefire.Player.id(p), p} end) |> Enum.into(%{}),
      table: Table.new()
    }
  end

  # TODO : new and bet are the same ? (blind bets -> start game ??)

  def bet(%__MODULE__{bets: bets} = game, player, amount)
      when is_atom(player) and is_number(amount) do
    players =
      if player not in Map.keys(game.players) do
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

    table =
      (players ++ [:dealer] ++ players)
      |> Enum.reduce(game.table, fn
        p, t -> Table.next_card(t) |> Table.card_to(p)
      end)

    %{game | table: table}
  end

  @doc ~s"""
    The play phase, where each player makes decisions, and cards are dealt
  """
  def play(%__MODULE__{players: players} = game) do
    for p <- Map.keys(players), reduce: game do
      game ->
        act = check_positions(game, p)
        # TODO :  a more clean/formal way to requesting from player,
        #    and player confirming action (to track for replays...)
        case act do
          :stand -> action(game, p, :stand)
          :hit -> action(game, p, :hit)
          :bust -> action(game, p, :bust)
          :blackjack -> action(game, p, :blackjack)
        end
    end

    # TODO : loop until the end of player turns
  end

  @doc ~s"""
    To the end, where the dealer get cards until >17
  """
  def resolve(%__MODULE__{players: players} = bj) do
    case check_positions(bj, :dealer) do
      :hit ->
        %{bj | table: bj.table |> Table.next_card() |> Table.card_to(:dealer)} |> resolve()

      :stand ->
        for p <- Map.keys(players), reduce: bj do
          bj ->
            # TODO : handle "push" when both are equal...
            if Table.check_hand(bj.table, p) > Table.check_hand(bj.table, :dealer) do
              player_win(bj, p)
            else
              player_lose(bj, p)
            end
        end

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

  def action(%__MODULE__{} = game, player, action)
      when action in [:hit, :stand] do
    if action == :hit do
      %{
        game
        | table:
            game.table
            |> Table.next_card()
            |> Table.card_to(player)
      }
    else
      game
    end
  end

  # TODO : compare with check_hand
  def check_positions(%__MODULE__{table: table}, :dealer) do
    dealer_pos =
      table
      |> Table.check_hand(:dealer)

    case dealer_pos do
      :bust -> :bust
      :blackjack -> :blackjack
      :stand -> :stand
      _v -> :hit
    end
  end

  def check_positions(%__MODULE__{table: table} = game, player) when is_atom(player) do
    player_pos =
      table
      |> Table.check_hand(player)

    case player_pos do
      # %{game | table: game.table |> Table.close_position(player)}
      :bust ->
        :bust

      :blackjack ->
        :blackjack

      value ->
        Surefire.Player.decide(
          game.players[player],
          "Position at #{value}. What to do ?",
          %{
            "Hit" => :hit,
            "Stand" => :stand
            # TODO : more options... Ref : https://en.wikipedia.org/wiki/Blackjack#Player_decisions
          }
        )
    end
  end

  def player_win(%__MODULE__{players: players, table: table} = game, player)
      when is_atom(player) do
    {player_bet, bets} = game.bets |> Bets.player_end(player)

    %{
      game
      | players:
          players |> Map.update(player, 0, fn p -> Surefire.Player.get(p, player_bet * 2) end),
        bets: bets,
        table: table |> Table.close_position(player)
    }
  end

  def player_lose(%__MODULE__{table: table} = game, player) when is_atom(player) do
    {_player_bet, bets} = game.bets |> Bets.player_end(player)
    %{game | bets: bets, table: table |> Table.close_position(player)}
  end
end
