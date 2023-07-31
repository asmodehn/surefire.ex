defmodule Blackjack.Game do
  @moduledoc ~s"""
  This module manages one game of blackjack.

  To run a quick game:

    iex> g = Blackjack.Game.new()
    iex> g = g |> Blackjack.Game.bet(:mememe, 21)
    iex> g = g |> Blackjack.Game.deal()
    iex> g = g |> Blackjack.Game.play()
    iex> g = g |> Blackjack.Game.resolve()
  """

  #  defmodule PlayerDone do
  #    defstruct id: nil, end: nil # bust / blackjack / value.
  #  end

  alias Blackjack.{Bets, Table}
  alias Blackjack.Event.{PlayerExit}

  import Blackjack.Deck, only: [deck: 0]

  @derive {Inspect, only: [:bets, :table]}
  defstruct bets: %Bets{},
            # TODO : number max of betting boxes ?
            table: %Table{},
            # This is a container for events, that have already been consumed
            # others are still considered "in flight"
            # TODO trace events and/or previous tables ???
            trace: []

  # Note: on player can play multiple  positions/boxes.
  # Note : one position can have multiple hands (on split - require another bet (but not an extra box) ?)

  def new() do
    %{
      %__MODULE__{}
      | table:
          Table.new(
            # default shoe of 3 decks...
            Enum.shuffle(deck() ++ deck() ++ deck())
          )
    }
  end

  def new(shoe) do
    %{%__MODULE__{} | table: Table.new(shoe)}
  end

  # TODO : Is this a new round ? only the first one ?
  def bet(%__MODULE__{bets: bets, trace: trace} = game, player_id, amount)
      when is_atom(player_id) and is_number(amount) do
    %{
      game
      | bets: bets |> Bets.player_bet(player_id, amount)
        #  ,        trace: trace ++ [:event_player_bet]  # TODO : proper event struct
    }
  end

  @doc ~s"""
    Only take in the game players who have already bet something...
  other player stay in game, but don't receive cards and cannot play.
  """
  def deal(%__MODULE__{bets: bets} = game) do
    table = Table.deal(game.table, Bets.players(bets))

    %{game | table: table}
  end

  def deal(%__MODULE__{table: table} = game, player_id) when is_atom(player_id) do
    %{game | table: table |> Table.deal(player_id)}
  end

  @doc ~s"""
    The play phase, where each player makes decisions, and cards are dealt
  """
  def play(%__MODULE__{table: table} = game, player_request, player_ids)
      when is_list(player_ids) do
    # TODO: make sure somehow that all players who did bet have a hand.
    played_game =
      for p <- player_ids, reduce: game do
        game ->
          IO.inspect("#{p} turn...")

          game |> play(player_request, p)
      end
  end

  def play(%__MODULE__{bets: bets, table: table} = game, player_request, player_id)
      when is_atom(player_id) do
    %{
      game
      | table:
          table
          |> Table.play(
            player_id,
            &player_request.(player_id, &1)
            # &Blackjack.Player.hit_or_stand(game.players[p], &1)
          )
    }
  end

  def play(%__MODULE__{bets: bets} = game, player_request) do
    game |> play(player_request, Bets.players(bets))
  end

  @doc """
  play/1 is useful for simple interactive play.
  it relies on player_choice/2 for prompting the user in IEx.
  """
  def play(%__MODULE__{bets: bets} = game) do
    game |> play(&player_choice/2)
  end

  @doc """
  The default player choice when nothing else is passed in play/2
  """
  defp player_choice(player_id, hand_value) when is_atom(player_id) do
    case ExPrompt.choose("#{player_id} with hand: #{hand_value} chooses ", [:hit, :stand]) do
      0 -> %Blackjack.Player.PlayCommand{id: player_id, command: :hit}
      _ -> %Blackjack.Player.PlayCommand{id: player_id, command: :stand}
    end
  end

  @doc ~s"""
    To the end, where the dealer get cards until >17
  """
  def resolve(%__MODULE__{bets: bets, table: table} = g) do
    {updated_table, win_or_lose} = table |> Table.resolve()

    for {p, wl} <- win_or_lose, reduce: {g, []} do
      {acc, evt} ->
        case wl do
          :win ->
            {updated_acc, generated_evts} = player_win(acc, p)
            {updated_acc, evt ++ generated_evts}

          :lose ->
            {updated_acc, generated_evts} = player_lose(acc, p)
            {updated_acc, evt ++ generated_evts}
        end
    end
  end

  def player_win(%__MODULE__{bets: bets} = game, player)
      when is_atom(player) do
    {player_bet, bets} = bets |> Bets.player_end(player)

    {
      %{game | bets: bets},
      [%Blackjack.Event.PlayerExit{id: player, gain: player_bet * 2}]
    }
  end

  def player_lose(%__MODULE__{bets: bets} = table, player) when is_atom(player) do
    {_player_bet, bets} = bets |> Bets.player_end(player)

    {
      %{table | bets: bets},
      [%Blackjack.Event.PlayerExit{id: player, gain: 0}]
    }
  end
end
