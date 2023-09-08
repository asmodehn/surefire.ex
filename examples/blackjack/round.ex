defmodule Blackjack.Round do
  @moduledoc ~s"""
  This module manages one game of blackjack.

  We care about the bets at this level.
    The stochastic process is in Table, and manages the "game" itself, without being concerned with bets.

  To run a quick game:

      iex> me = Surefire.IExPlayer.new(:mememe, 100)
      iex> {av, me} = me |> Surefire.Player.avatar("bj_avatar", 50)
      iex> g = Blackjack.Round.new("demo round", Blackjack.Card.deck() |> Enum.shuffle())
      iex> g = g |> Blackjack.Round.enter(av)
      iex> g = g |> Blackjack.Round.deal()
      iex> g = g |> Blackjack.Round.play()
      iex> g = g |> Blackjack.Round.resolve()
  """

  alias Blackjack.{Bets, Table, Avatar}
  #  alias Blackjack.Event.{PlayerExit}

  alias Surefire.Accounting.{Account, Transaction}

  @derive {Inspect, only: [:bets, :avatars, :table]}

  defstruct id: "the_roundWIP",
            # TODO : number max of betting boxes ?
            bets: %Bets{},
            avatars: %{},
            ledger_pid: nil,
            account_id: nil,
            table: %Table{}

  # Note: one player can play multiple  positions/boxes.
  # Note : one position can have multiple hands (on split - require another bet (but not an extra box) ?)

  # TODO : no ledger -> dry run -> no transactions in this round...
  def new(id, shoe) do
    %{
      %__MODULE__{}
      | id: id,
        table: Table.new(shoe)
    }
  end

  def new(id, shoe, ledger_pid, account_id)
      when is_pid(ledger_pid) and is_atom(account_id) do
    %{
      %__MODULE__{}
      | id: id,
        table: Table.new(shoe),
        ledger_pid: ledger_pid,
        account_id: account_id
    }
  end

  # rename to "enter" or something similar ??
  def enter(%__MODULE__{bets: bets, avatars: avatars} = round, %Surefire.Avatar{} = avatar) do
    # TODO : make sure avatar implements avatar behaviour...

    {amount, avatar} =
      if round.ledger_pid == nil do
        # TODO : use concept of `DryAvatar` instead
        Avatar.fake_bet(avatar)
      else
        Avatar.bet(avatar, round.ledger_pid, round.account_id)
        # TODO : amount or full transaction id ??
      end

    %{
      round
      | bets: bets |> Bets.player_bet(avatar.id, amount),
        avatars: avatars |> Map.put(avatar.id, avatar)
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
  def play(%__MODULE__{} = game, avatar_ids)
      when is_list(avatar_ids) do
    for a_id <- avatar_ids, reduce: game do
      game -> game |> play(a_id)
    end
  end

  def play(%__MODULE__{table: table} = game, %Surefire.Avatar{} = avatar) do
    %{
      game
      | table:
          table
          |> Table.play(
            avatar.id,
            fn ph, dh -> Avatar.hit_or_stand(avatar, ph, dh) end
          )
    }
  end

  def play(%__MODULE__{} = game, :dealer) do
    # TODO : double check this !
    game |> play(%Blackjack.Dealer{})
  end

  def play(%__MODULE__{avatars: avatars} = game, avatar_id) do
    game |> play(avatars[avatar_id])
  end

  @doc """
  play/1 is useful for simple interactive play.
  it relies on player_choice/2 for prompting the user in IEx.
  """
  def play(%__MODULE__{avatars: avatars} = game) do
    game
    # TODO : dealer play here instead of in resolve !!
    |> play(Map.keys(avatars))

    # TODO : maybe better to do a map() on values directly ??
  end

  # TODO : resolve and play should be the same (bust allowed during play, void possible in play, etc.)
  @doc ~s"""
    To the end, where the dealer get cards until >17
  """
  def resolve(%__MODULE__{table: table, avatars: avatars} = g) do
    updated_table =
      table
      |> Table.play(:dealer, fn
        dh, dh -> Blackjack.Avatar.hit_or_stand(%Blackjack.Dealer{}, dh, dh)
      end)
      |> Table.resolve()

    if updated_table.result == :void do
      {%{g | table: updated_table}, [:game_is_void]}
    else
      for {p, wl} <- updated_table.result, reduce: {%{g | table: updated_table}, []} do
        {acc, evt} ->
          case wl do
            :win ->
              {updated_acc, generated_evts} = player_win(acc, avatars[p])
              {updated_acc, evt ++ generated_evts}

            :lose ->
              {updated_acc, generated_evts} = player_lose(acc, avatars[p])
              {updated_acc, evt ++ generated_evts}
          end
      end
    end
  end

  def player_win(%__MODULE__{bets: bets} = game, avatar) do
    {player_bet, bets} = bets |> Bets.player_end(avatar.id)

    {
      %{game | bets: bets},
      # TODO : review this as a transaction
      [%Blackjack.Event.PlayerExit{id: avatar.player_id, gain: player_bet * 2}]
    }
  end

  def player_lose(%__MODULE__{bets: bets} = table, avatar) do
    {_player_bet, bets} = bets |> Bets.player_end(avatar.id)

    {
      %{table | bets: bets},
      # TODO : review this as a transaction
      [%Blackjack.Event.PlayerExit{id: avatar.player_id, gain: 0}]
    }
  end

  #  defimpl Surefire.Round do
  #    def id(%Blackjack.Round{} = round) do
  #      round.id
  #    end
  #  end
end
