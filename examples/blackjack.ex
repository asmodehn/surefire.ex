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
  IO.puts("Create your player data : > me = Blackjack.Player.new_interactive()")
  IO.puts("Start a game of Blackjack : > bj = Blackjack.new() ")
  IO.puts("Place a bet : > Blackjack.bet(bj, me, 51)")
  IO.puts("Deal cards : > Blackjack.deal(bj)")
  IO.puts("Interactive Play : > Blackjack.play(bj)")
  IO.puts("Resolve : > Blackjack.resolve(bj)")

  alias Blackjack.Table
  alias Blackjack.Event.{PlayerExit}

  #    @derive {Inspect, only: [:players]}
  defstruct players: %{},
            table: %Table{}

  # TODO : we should add the total house bank amount here...

  @doc """
    Register players for a new game.
  """
  def new() do
    %__MODULE__{
      table: Table.new()
    }
  end

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
    %{played_game | table: played_game.table |> Table.play(:dealer)}
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
