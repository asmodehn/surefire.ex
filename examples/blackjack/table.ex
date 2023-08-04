defmodule Blackjack.Table do
  @moduledoc """
  `Blackjack.Table` implements blackjack rules for a table.
  """
  alias Blackjack.{Hand, Bets}

  @derive {Inspect, only: [:dealer, :players, :result]}
  defstruct void_under: 1,
            shoe: [],
            dealer: %Hand{},
            players: %{},
            result: []

  @type t :: %__MODULE__{
          void_under: pos_integer,
          shoe: List.t(),
          dealer: Hand.t(),
          players: Map.t(),
          result: Keyword.t() | :void
        }

  # Note: on player can play multiple  positions/boxes.
  # Note : one position can have multiple hands (on split - require another bet (but not an extra box) ?)

  @doc """
  Builds a new table with the given parameter as shoe.
  option :void_under indicates the minimum number of cards to keep in the shoe, or the round is declared void.
  """
  def new(shoe \\ [], opts \\ [void_under: 1]) when is_list(shoe) do
    void_under = abs(Keyword.get(opts, :void_under, 1))

    %__MODULE__{
      void_under: void_under,
      shoe: shoe
    }
  end

  # TODO : reshuffle after the shoe has been used "enough". between rounds only...
  # => done by a new table => in game module instead ?
  # If round cannot be finished with current shoe -> void, reshuffle and start again.

  # TODO : prevent creating a player caller "dealer"... or work around the issue somehow ??
  @doc """
  Deals a card from the shoe to a player, to the :dealer, or to a list of players
  """
  def deal(%__MODULE__{shoe: shoe, void_under: void_under} = table, _)
      when length(shoe) < void_under do
    %{table | result: :void}
  end

  def deal(%__MODULE__{shoe: shoe, void_under: void_under, dealer: dealer_hand} = table, :dealer)
      when length(shoe) >= void_under do
    %{
      table
      | shoe: shoe |> Enum.drop(1),
        dealer: dealer_hand |> Hand.add_card(shoe |> Enum.take(1))
    }
  end

  # TODO : hand as just a list of cards (no struct) ???
  def deal(%__MODULE__{shoe: shoe, void_under: void_under, players: players} = table, player_id)
      when is_atom(player_id) and length(shoe) >= void_under do
    %{
      table
      | shoe: shoe |> Enum.drop(1),
        players:
          players
          |> Map.put(
            player_id,
            players[player_id] |> Hand.add_card(shoe |> Enum.take(1))
          )
    }
  end

  def deal(%__MODULE__{} = table, player_ids) when is_list(player_ids) do
    player_ids
    |> Enum.reduce(table, fn
      p, t -> t |> deal(p)
    end)

    # TODO : check of bust or blackjack here already... ??
  end

  @doc """
  Player turn on the table.
  If a player has no card, nothing changes.
  Same if players hand value is an atom (bust or blackjack).
  Otherwise, a card may be dealt.
  """
  def play(%__MODULE__{players: players} = table, player_id, player_request) do
    if is_nil(players[player_id]) or is_atom(players[player_id].value) do
      # Ref from wikipedia:
      # A hand can "hit" as often as desired until the total is 21 or more.
      # Players must stand on a total of 21.
      table
    else
      %Blackjack.Player.PlayCommand{id: ^player_id, command: act} =
        player_request.(players[player_id].value)

      # TODO :  a more clean/formal way to requesting from player,
      #    and player confirming action (to track for replays...)
      case act do
        :stand ->
          table

        :hit ->
          table
          |> deal(player_id)
          |> play(player_id, player_request)
      end
    end
  end

  # TODO : resolve should be same as play...
  @doc """
  Deals cards to the dealer until his hand has value >=17
  Decides if a player :win or :lose
  """

  #  def resolve(%__MODULE__{} = table, _)
  #      when length(table.shoe) < table.void_under do
  #    %{table | result: :void}
  #  end
  def resolve(%__MODULE__{dealer: dealer_hand, result: result} = table, :dealer)
      when result != :void and is_integer(dealer_hand.value) and dealer_hand.value < 17 do
    table
    # deal one card more to the dealer (if available in shoe...)
    |> deal(:dealer)
    # and recurse until >= 17 or bust or blackjack
    |> resolve(:dealer)
  end

  def resolve(%__MODULE__{} = table, :dealer) do
    # identity by default => table doesnt change
    table
  end

  def resolve(%__MODULE__{players: players, result: result} = table, player)
      when is_atom(player) and is_list(result) do
    # TODO : handle "push" when both are equal...
    hand_comp = Hand.compare(players[player], table.dealer)
    # TODO : review actual cases (with tests) here
    if hand_comp == :gt do
      %{table | result: result |> Keyword.put(player, :win)}
    else
      %{table | result: result |> Keyword.put(player, :lose)}
    end
  end

  def resolve(%__MODULE__{players: players} = table) do
    updated_table = table |> resolve(:dealer)

    if updated_table.result == :void do
      updated_table
    else
      for p <- Map.keys(players), reduce: updated_table do
        acc_table -> resolve(acc_table, p)
      end
    end
  end
end
