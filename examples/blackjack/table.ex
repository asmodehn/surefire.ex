defmodule Blackjack.Table do
  @moduledoc """
  `Blackjack.Table` implements blackjack rules for a table.
  """
  alias Blackjack.{Hand, Bets}

  @derive {Inspect, only: [:dealer, :players]}
  defstruct shoe: [],
            dealer: %Hand{},
            players: %{}

  # Note: on player can play multiple  positions/boxes.
  # Note : one position can have multiple hands (on split - require another bet (but not an extra box) ?)

  @doc """
  Builds a new table with the given parameter as shoe
  """
  def new(shoe \\ []) when is_list(shoe) do
    %__MODULE__{
      shoe: shoe
    }
  end

  # TODO : prevent creating a player caller "dealer"... or work around the issue somehow ??
  @doc """
  Deals a card from the shoe to a player, to the :dealer, or to a list of players
  """
  def deal(%__MODULE__{shoe: shoe, dealer: dealer_hand} = table, :dealer) do
    {new_hand, new_shoe} = Blackjack.Deck.deal(shoe, dealer_hand)
    %{table | shoe: new_shoe, dealer: new_hand}
  end

  def deal(%__MODULE__{shoe: shoe, players: players} = table, player_id)
      when is_atom(player_id) do
    player_hand = players[player_id]

    {new_hand, new_shoe} =
      case player_hand do
        # TODO : maybe the other way ? hand receiving a card from a enum of cards???
        nil -> Blackjack.Deck.deal(shoe, Blackjack.Hand.new())
        hand -> Blackjack.Deck.deal(shoe, hand)
      end

    %{table | shoe: new_shoe, players: players |> Map.put(player_id, new_hand)}
  end

  def deal(%__MODULE__{} = table, player_ids) when is_list(player_ids) do
    (player_ids ++ [:dealer] ++ player_ids)
    |> Enum.reduce(table, fn
      p, t -> t |> deal(p)
    end)

    # TODO : check of bust or blackjack here already...
  end

  @doc """
  Player turn on the table. identity if position is an atom (bust or blackjack).
  Otherwise, a card may be dealt.
  """
  def play(%__MODULE__{players: players} = table, player_id, player_request) do
    if is_atom(players[player_id].value) do
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

  @doc """
  Deals cards to the dealer until his hand has value >=17
  Decides if a player :win or :lose
  """
  def resolve(%__MODULE__{dealer: dealer_hand} = table, :dealer)
      when dealer_hand.value >= 17
      when is_atom(dealer_hand.value) do
    table
  end

  def resolve(%__MODULE__{} = table, :dealer) do
    table
    # deal one card more to the dealer
    |> deal(:dealer)
    # and recurse until >= 17 or bust or blackjack
    |> resolve(:dealer)
  end

  def resolve(%__MODULE__{players: players} = table, player) when is_atom(player) do
    # TODO : handle "push" when both are equal...
    hand_comp = Hand.compare(players[player], table.dealer)
    # TODO : review actual cases (with tests) here
    if hand_comp == :gt do
      {table, :win}
    else
      {table, :lose}
    end
  end

  def resolve(%__MODULE__{players: players} = table) do
    for p <- Map.keys(players), reduce: {table |> resolve(:dealer), []} do
      {acc_table, win_or_lose} ->
        {updated_table, win_lose} = resolve(acc_table, p)
        {updated_table, [{p, win_lose} | win_or_lose]}
    end
  end
end
