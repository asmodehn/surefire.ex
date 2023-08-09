defmodule Blackjack.Round do
  @moduledoc ~s"""
  This module manages one game of blackjack.

  To run a quick game:

    iex> g = Blackjack.Round.new()
    iex> g = g |> Blackjack.Round.bet(:mememe, 21)
    iex> g = g |> Blackjack.Round.deal()
    iex> g = g |> Blackjack.Round.play()
    iex> g = g |> Blackjack.Round.resolve()
  """

  #  defmodule PlayerDone do
  #    defstruct id: nil, end: nil # bust / blackjack / value.
  #  end

  alias Blackjack.{Bets, Table, Card}
  alias Blackjack.Event.{PlayerExit}

  @derive {Inspect, only: [:bets, :table]}
  # TODO : add full player structure at this stage -> allow dispatching from here depending on implementation...
  defstruct bets: %Bets{},
            # TODO : number max of betting boxes ? in table instead (has to match the shoe size...) ??
            table: %Table{},
            # This is a container for events, that have already been consumed
            # others are still considered "in flight"
            # TODO trace events and/or previous tables ???
            trace: []

  # Note: on player can play multiple  positions/boxes.
  # Note : one position can have multiple hands (on split - require another bet (but not an extra box) ?)
  #
  #  def new() do
  #    %{
  #      %__MODULE__{}
  #      | table:
  #          Table.new(
  #            # default shoe of 3 decks...
  #            Enum.shuffle(Card.deck() ++ Card.deck() ++ Card.deck())
  #          )
  #    }
  #  end

  def new(shoe \\ []) do
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
  def deal(%__MODULE__{bets: bets} = game), do: deal(game, Bets.players(bets))

  def deal(%__MODULE__{} = game, player_ids) when is_list(player_ids) do
    table = Table.deal(game.table, player_ids ++ [:dealer] ++ player_ids)

    %{game | table: table}
  end

  def deal(%__MODULE__{bets: bets, table: table} = game, player_id)
      when is_atom(player_id) do
    if player_id in Bets.players(bets) do
      %{game | table: table |> Table.deal(player_id)}
    else
      # no bet -> no card
      game
    end
  end

  @doc ~s"""
    The play phase, where each player makes decisions, and cards are dealt
  """
  def play(%__MODULE__{table: table} = game, player_request, player_ids)
      when is_list(player_ids) do
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
            # TODO : expose entire avatar to game -> dispatch here to proper impl
            fn ph, dh -> player_request.(ph, dh) end
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
    game
    |> play(fn
      ph, dh -> Blackjack.Avatar.IEx.hit_or_stand(ph, dh)
    end)
  end

  # TODO : resolve and play should be the same (bust allowed during play, void possible in play, etc.)
  @doc ~s"""
    To the end, where the dealer get cards until >17
  """
  def resolve(%__MODULE__{bets: bets, table: table} = g) do
    updated_table = table |> Table.play(:dealer) |> Table.resolve()

    if updated_table.result == :void do
      {%{g | table: updated_table}, [:game_is_void]}
    else
      updated_table.result |> IO.inspect()

      for {p, wl} <- updated_table.result, reduce: {%{g | table: updated_table}, []} do
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
