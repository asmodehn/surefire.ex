defmodule Blackjack.Round do
  @moduledoc ~s"""
  This module manages one game of blackjack.

  To run a quick game:

      iex> me = Blackjack.Avatar.IEx.new(:mememe)
      iex> g = Blackjack.Round.new(Blackjack.Card.deck() |> Enum.shuffle())
      iex> g = g |> Blackjack.Round.bet(me, 21)
      iex> g = g |> Blackjack.Round.deal()
      iex> g = g |> Blackjack.Round.play()
      iex> g = g |> Blackjack.Round.resolve()
  """

  #  defmodule PlayerDone do
  #    defstruct id: nil, end: nil # bust / blackjack / value.
  #  end

  alias Blackjack.{Bets, Table, Avatar}
  #  alias Blackjack.Event.{PlayerExit}

  @derive {Inspect, only: [:bets, :table]}

  # TODO : bets part of avatar ? => would make sense as part of surefire...
  defstruct bets: %Bets{},
            avatars: %{},
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

  # rename to "enter" or something similar ??
  def bet(%__MODULE__{bets: bets, trace: trace} = round, avatar, amount)
      when is_number(amount) do
    # TODO : make sure avatar implements avatar behaviour...
    %{
      round
      | bets: bets |> Bets.player_bet(Avatar.id(avatar), amount),
        avatars: round.avatars |> Map.put(Avatar.id(avatar), avatar)
        #  ,        trace: trace ++ [:event_player_bet]  # TODO : proper event struct
    }
  end

  @doc ~s"""
    Only take in the game players who have already bet something...
  other player stay in game, but don't receive cards and cannot play.
  """
  def deal(%__MODULE__{avatars: avatars} = game), do: deal(game, Map.keys(avatars))

  def deal(%__MODULE__{} = game, avatar_ids) when is_list(avatar_ids) do
    table = Table.deal(game.table, avatar_ids ++ [:dealer] ++ avatar_ids)

    %{game | table: table}
  end

  def deal(%__MODULE__{avatars: avatars, table: table} = game, avatar_id)
      when is_atom(avatar_id) do
    if avatar_id in Map.keys(avatars) do
      %{game | table: table |> Table.deal(avatar_id)}
    else
      # no bet -> no card
      game
    end
  end

  @doc ~s"""
    The play phase, where each player makes decisions, and cards are dealt
  """
  def play(%__MODULE__{table: table, avatars: avatars} = game, avatar_ids)
      when is_list(avatar_ids) do
    for a_id <- avatar_ids, reduce: game do
      game ->
        IO.inspect("#{a_id} turn...")

        game |> play(a_id)
    end
  end

  def play(%__MODULE__{table: table, avatars: avatars} = game, :dealer) do
    game |> play(%Blackjack.Dealer{})
  end

  def play(%__MODULE__{table: table, avatars: avatars} = game, avatar_id)
      when is_atom(avatar_id) do
    game |> play(avatars[avatar_id])
  end

  def play(%__MODULE__{bets: bets, table: table} = game, avatar) do
    %{
      game
      | table:
          table
          |> Table.play(
            Avatar.id(avatar),
            # TODO : does catpure works well with protocol dispatch ??
            fn ph, dh -> Avatar.hit_or_stand(avatar, ph, dh) end
          )
    }
  end

  @doc """
  play/1 is useful for simple interactive play.
  it relies on player_choice/2 for prompting the user in IEx.
  """
  def play(%__MODULE__{avatars: avatars} = game) do
    game
    # TODO : dealer play here instead of in resolve ??
    |> play(Map.keys(avatars))

    # TODO : maybe better to do a map() on values directly ??
  end

  # TODO : resolve and play should be the same (bust allowed during play, void possible in play, etc.)
  @doc ~s"""
    To the end, where the dealer get cards until >17
  """
  def resolve(%__MODULE__{bets: bets, table: table} = g) do
    updated_table =
      table
      |> Table.play(:dealer, fn
        dh, dh -> Blackjack.Avatar.hit_or_stand(%Blackjack.Dealer{}, dh, dh)
      end)
      |> Table.resolve()

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

  def player_win(%__MODULE__{bets: bets} = game, avatar)
      when is_atom(avatar) do
    {player_bet, bets} = bets |> Bets.player_end(avatar)

    {
      %{game | bets: bets},
      [%Blackjack.Event.PlayerExit{id: avatar, gain: player_bet * 2}]
    }
  end

  def player_lose(%__MODULE__{bets: bets} = table, avatar) when is_atom(avatar) do
    {_player_bet, bets} = bets |> Bets.player_end(avatar)

    {
      %{table | bets: bets},
      [%Blackjack.Event.PlayerExit{id: avatar, gain: 0}]
    }
  end
end
