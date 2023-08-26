defmodule Blackjack.Table do
  @moduledoc """
  `Blackjack.Table` implements blackjack rules for a table.


  """
  alias Blackjack.Hand

  @derive {Inspect, only: [:dealer, :players, :result]}
  defstruct void_under: 1,
            # TODO : maybe shoe is special and can be its own struct ?
            shoe: [],
            dealer: %Hand{},
            # TODO confusing : players -> hands
            players: %{},
            # TODO : maybe only hte result of a function (resolve/1 ?)
            result: %{}

  @type t :: %__MODULE__{
          void_under: pos_integer,
          shoe: List.t(),
          dealer: Hand.t(),
          players: Map.t(),
          result: Map.t() | :void
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
  # => done by a new table/round => in game/round module instead ?
  # If round cannot be finished with current shoe -> void, reshuffle and start again.

  # TODO : prevent creating a player caller "dealer"... or work around the issue somehow ??
  @doc """
  Deals a card from the shoe to a player, to the :dealer, or to a list of players
  """
  def deal(%__MODULE__{shoe: shoe, void_under: void_under} = table, _)
      when length(shoe) < void_under do
    %{table | result: :void}
  end

  def deal(%__MODULE__{} = table, player_ids) when is_list(player_ids) do
    player_ids
    |> Enum.reduce(table, fn
      p, t -> t |> deal(p)
    end)

    # TODO : check of bust or blackjack here already... ??
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
      when length(shoe) >= void_under do
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

  @doc """
  Player (or dealer) turn on the table.
  - If result is void, nothing changes (identity)
  - If a player has no card, nothing changes (identity)
  - If players hand value is an atom (bust or blackjack), nothing changes (identity)
  Otherwise, a card may be dealt, if player decides to :hit.
  """

  # TODO : get rid of this after simplify call for player
  def play(%__MODULE__{result: :void} = table, _, _) do
    table
  end

  def play(%__MODULE__{dealer: dealer_hand} = table, :dealer, dealer_request) do
    full_table =
      if Hand.is_playable?(dealer_hand) do
        case dealer_request.(dealer_hand, dealer_hand) do
          :hit ->
            table
            |> deal(:dealer)
            # recurse until :stand
            |> play(:dealer, dealer_request)

          _ ->
            table
        end
      else
        # otherwise bust or blackjack -> stop
        table
      end

    full_table |> resolve()
  end

  def play(%__MODULE__{players: players} = table, player_id, player_request)
      when is_map_key(players, player_id) do
    full_table =
      if Hand.is_playable?(players[player_id]) do
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
      else
        table
      end

    full_table |> resolve(player_id)
  end

  # TODO : resolve should be same as play...
  @doc """
  Deals cards to the dealer until his hand has value >=17
  Decides if a player :win or :lose
  """

  def resolve(%__MODULE__{result: :void} = table, _) do
    table
  end

  def resolve(
        %__MODULE__{players: avatars, dealer: dealer_hand, result: result} = table,
        avatar_id
      )
      when is_map_key(avatars, avatar_id) and (is_atom(dealer_hand) or dealer_hand.value >= 17) do
    # TODO : handle "push" when both are equal...
    hand_comp = Hand.compare(avatars[avatar_id], table.dealer)
    # TODO : review actual cases (with tests) here
    if hand_comp == :gt do
      %{table | result: result |> Map.put(avatar_id, :win)}
    else
      %{table | result: result |> Map.put(avatar_id, :lose)}
    end
  end

  def resolve(%__MODULE__{players: players, result: result} = table, player)
      when is_map_key(players, player) do
    case players[player].value do
      :bust -> %{table | result: result |> Map.put(player, :lose)}
      # blackjack must wait for all players to play and dealer to draw his last card
      :blackjack -> table
      _ -> table
    end
  end

  def resolve(%__MODULE__{result: :void} = table) do
    table
  end

  def resolve(%__MODULE__{players: players, dealer: dealer_hand} = table)
      when is_atom(dealer_hand) or dealer_hand.value >= 17 do
    for p <- Map.keys(players), reduce: table do
      acc_table -> resolve(acc_table, p)
    end
  end
end
