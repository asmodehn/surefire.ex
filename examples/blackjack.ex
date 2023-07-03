

defmodule Blackjack.Bets do
  defstruct bets: []

  # Note: bets seems to be like monad : a state embedded deep inside a process...
  # Maybe there is a way to leverage that for better design ?


  def player_bet(%__MODULE__{} = b, player, bet) do
    %{b | bets: Keyword.update(b.bets, player, bet, fn v -> v + bet end)}
  end

  def players(%__MODULE__{bets: b}) do
    Keyword.keys(b)
  end

end


defmodule Blackjack do
  @moduledoc """
    A Blackjack implementation, using Surefire.
  """

  alias Blackjack.{Bets, Table}

#  @derive {Inspect, only: [:bets, :table]}
  defstruct players: %{},
            bets: %Bets{},
            table: %Table{}


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
    players = if player not in Map.keys(game.players) do
      game.players ++ [player]
    else
      game.players
    end

    %{game | players: Map.update!(players, player, fn p ->  p |> Surefire.Player.bet(amount) end),
      bets: bets |> Bets.player_bet(player, amount)
    }
  end

  @doc ~s"""
    Only take in the game players who have already bet something...
  other player stay in game, but don't receive cards and cannot play.
  """
  def deal(%__MODULE__{bets: bets} = game) do
    players = Bets.players(bets)
    %{game | table: game.table
            |> Table.deal_card( players ++ [:dealer])
            |> Table.deal_card( players ++ [:dealer])
    }
  end


  def action(%__MODULE__{} = game, player, action)
    when action in [:hit, :stand] do

    if action == :hit do
      %{game | table: game.table
              |> Table.deal_card(player)
      }
    else
      game
    end
  end


    def check_positions(%__MODULE__{table: table}, :dealer) do

      dealer_pos = table
      |> Table.check_value(:dealer)

      case dealer_pos do
        :bust -> for p <- table.players, do: Surefire.Player.get(p, 0)
        :blackjack ->  for p <- table.players, do: Surefire.Player.get(p, 0)
        _ -> IO.gets(:stdio, "What does the dealer think ?") |> IO.inspect()
      end

    end

    def check_positions(%__MODULE__{table: table} = game, player) do

      player_pos = table
      |> Table.check_value(player)

      case player_pos do
        :bust -> %{game | table: game.table |> Table.player_bust(player)}
        :blackjack ->  :stand # wait for dealer check
        _ -> Surefire.Player.decide(player, "Hit it ? or Stand ?", ~w(hit stand)) |> IO.inspect()
      end

    end

end


