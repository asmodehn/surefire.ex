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
      iex> g = g |> Blackjack.Round.play(:dealer)
      iex> g = g |> Blackjack.Round.resolve()
  """

  alias Blackjack.{Bets, Table, Avatar}
  #  alias Blackjack.Event.{PlayerExit}

  alias Surefire.Accounting.{Account, Transaction, AccountID}

  @derive {Inspect, only: [:bets, :avatars, :table]}

  defstruct id: "the_roundWIP",
            # TODO : number max of betting boxes ?
            # TODO : add transactions id in bets ?
            bets: %{},
            avatars: %{},
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

  def new(id, shoe, %AccountID{} = account_id) do
    %{
      %__MODULE__{}
      | id: id,
        table: Table.new(shoe),
        account_id: account_id
    }
  end

  # rename to "enter" or something similar ??
  def enter(%__MODULE__{bets: bets, avatars: avatars} = round, %Surefire.Avatar{} = avatar) do
    # TODO : make sure avatar implements avatar behaviour...

    {amount, avatar} =
      if round.account_id == nil do
        # TODO : use concept of `DryAvatar` instead
        Avatar.fake_bet(avatar)
      else
        Avatar.bet(avatar, round.account_id)
        # TODO : amount or full transaction id ??
      end

    # TMP
    # TODO : define game_event relative to game state (player hand > dealer hand)
    # TODO : Note game_event is related to betting box somehow
    game_event = avatar.id

    %{
      round
      | bets:
          bets
          |> Surefire.Bets.stake(game_event, avatar.id, amount),

        #              |> Bets.player_bet(avatar.id, amount),
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
  def play(%__MODULE__{avatars: avatars} = game) do
    for a_id <- Map.keys(avatars), reduce: game do
      game -> game |> play(a_id)
    end
  end

  def play(%__MODULE__{} = game, :dealer) do
    game |> play(%Blackjack.Dealer{})
  end

  def play(%__MODULE__{avatars: avatars} = game, avatar_id)
      when is_atom(avatar_id) and is_map_key(avatars, avatar_id) do
    game |> play(avatars[avatar_id])
  end

  def play(%__MODULE__{table: table} = game, avatar) do
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

  # TODO : resolve and play should be the same (bust allowed during play, void possible in play, etc.)
  @doc ~s"""
    To the end, where the dealer get cards until >17
  """
  def resolve(%__MODULE__{table: table, avatars: avatars} = g) do
    updated_table =
      table
      |> Table.resolve()

    if updated_table.result == :void do
      {%{g | table: updated_table}, [:game_is_void]}
    else
      # TODO : fix game_event to simplify this...
      updated_bets =
        for {p, wl} <- updated_table.result, reduce: g.bets do
          acc ->
            case wl do
              :win ->
                acc
                |> Surefire.Bets.winnings(
                  p,
                  fn
                    s -> %{s | amount: s.amount * 2}
                  end,
                  # To not lose stake of yet unparsed player result
                  fn s -> s end
                )

              :lose ->
                acc
                |> Surefire.Bets.winnings(
                  p,
                  fn
                    s -> %{s | amount: s.amount * 0}
                  end,

                  # To keep other players' result
                  fn s -> s end
                )
            end
        end

      %{g | table: updated_table, bets: updated_bets}
    end
  end

  defimpl Surefire.Game do
    def id(%Blackjack.Round{} = round) do
      round.id
    end

    def enter(%Blackjack.Round{} = round, avatar) do
      Blackjack.Round.enter(round, avatar)
    end

    @doc """
    play/1 is useful for simple interactive play.
      To run a quick game:

      iex> me = Surefire.IExPlayer.new(:mememe, 100)
      iex> {av, me} = me |> Surefire.Player.avatar("bj_avatar", 50)
      iex> g = Blackjack.Round.new("demo round", Blackjack.Card.deck() |> Enum.shuffle())
      iex> g = g |> Surefire.Game.enter(av)
      iex> g = g |> Surefire.Game.play()

    """
    def play(%Blackjack.Round{avatars: avatars} = game) do
      game
      |> Blackjack.Round.deal()
      |> Blackjack.Round.play()
      |> Blackjack.Round.play(:dealer)
      |> Blackjack.Round.resolve()
    end
  end
end
