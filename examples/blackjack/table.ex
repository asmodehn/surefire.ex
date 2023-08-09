defmodule Blackjack.Table do
  @moduledoc """
  `Blackjack.Table` implements blackjack rules for a table.
  """
  alias Blackjack.{Hand, Bets}

  @derive {Inspect, only: [:dealer, :players, :result]}
  defstruct void_under: 1,
            # TODO : maybe shoe is special and can be its own struct ?
            shoe: [],
            dealer: %Hand{},
            # confusing : players -> hands
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
  Player (or dealer) turn on the table.
  - If result is void, nothing changes (identity)
  - If a player has no card, nothing changes (identity)
  - If players hand value is an atom (bust or blackjack), nothing changes (identity)
  Otherwise, a card may be dealt, if player decides to :hit.
  """

  def play(%__MODULE__{result: :void} = table, _) do
    table
  end

  # TODO : get rid of this after simplify call for player
  def play(%__MODULE__{result: :void} = table, _, _) do
    table
  end

  def play(%__MODULE__{dealer: dealer_hand} = table, :dealer)
      when is_integer(dealer_hand.value) do
    play(table, :dealer, &Blackjack.Dealer.hit_or_stand/2)
  end

  def play(%__MODULE__{shoe: shoe, dealer: dealer_hand} = table, :dealer, dealer_request)
      when is_integer(dealer_hand.value) do
    # otherwise bust or blackjack -> stop # TODO : proper hand module function
    full_table =
      case dealer_request.(dealer_hand, dealer_hand) do
        :hit ->
          table
          |> deal(:dealer)
          # recurse until :stand
          |> play(:dealer)

        _ ->
          table
      end

    full_table |> resolve()
  end

  def play(%__MODULE__{} = table, :dealer) do
    table
  end

  def play(%__MODULE__{players: players} = table, player_id) do
    if is_nil(players[player_id]) or is_atom(players[player_id].value) do
      # Ref from wikipedia:
      # A hand can "hit" as often as desired until the total is 21 or more.
      # Players must stand on a total of 21.
      table
    else
      play(table, player_id, &Blackjack.Avatar.IEx.hit_or_stand/2)
    end
  end

  def play(%__MODULE__{players: players} = table, player_id, player_request) do
    if is_nil(players[player_id]) or is_atom(players[player_id].value) do
      # Ref from wikipedia:
      # A hand can "hit" as often as desired until the total is 21 or more.
      # Players must stand on a total of 21.
      table
    else
      # TODO :  a more clean/formal way to requesting from player,
      #    and player confirming action (to track for replays...)
      case player_request.(players[player_id], table.dealer) do
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

  def resolve(%__MODULE__{result: :void} = table) do
    table
  end

  def resolve(%__MODULE__{result: :void} = table, _) do
    table
  end

  def resolve(%__MODULE__{players: players, dealer: dealer_hand, result: result} = table, player)
      when is_atom(dealer_hand) or
             (dealer_hand.value >= 17 and
                is_atom(player) and is_list(result)) do
    # TODO : handle "push" when both are equal...
    hand_comp = Hand.compare(players[player], table.dealer)
    # TODO : review actual cases (with tests) here
    if hand_comp == :gt do
      %{table | result: result |> Keyword.put(player, :win)}
    else
      %{table | result: result |> Keyword.put(player, :lose)}
    end
  end

  def resolve(%__MODULE__{players: players, dealer: dealer_hand} = table)
      when is_atom(dealer_hand) or dealer_hand.value >= 17 do
    for p <- Map.keys(players), reduce: table do
      acc_table -> resolve(acc_table, p)
    end
  end
end
