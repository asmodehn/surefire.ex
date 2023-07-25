defmodule Blackjack.Table do
  alias Blackjack.{Hand, Bets}

  import Blackjack.Deck, only: [deck: 0]

  # TODO : rounds, one game after another, using the same shoe.
  @derive {Inspect, only: [:dealer, :bets, :positions]}
  defstruct shoe: [],
            # TODO : maybe move bets out of table (different concerns...) ?
            bets: %Bets{},
            dealer: %Hand{},
            # TODO : number max of betting boxes !
            positions: %{}

  # Note: on player can play multiple  positions/boxes.
  # Note : one position can have multiple hands (on split - require another bet (but not an extra box) ?)

  def new(_decks \\ 3) do
    %__MODULE__{
      shoe: Enum.shuffle(deck()) ++ Enum.shuffle(deck()) ++ Enum.shuffle(deck())
    }
  end

  # TODO : prevent creating a player caller "dealer"...) or work around the issue somehow ??
  def deal_card_to(%__MODULE__{shoe: shoe, dealer: dealer_hand} = table, :dealer) do
    {new_hand, new_shoe} = Blackjack.Deck.deal(shoe, dealer_hand)
    %{table | shoe: new_shoe, dealer: new_hand}
  end

  def deal_card_to(%__MODULE__{shoe: shoe, positions: positions} = table, player_id)
      when is_atom(player_id) do
    player_hand = positions[player_id]

    {new_hand, new_shoe} =
      case player_hand do
        # TODO : maybe the other way ? hand receiving a card from a enum of cards???
        nil -> Blackjack.Deck.deal(shoe, Blackjack.Hand.new())
        hand -> Blackjack.Deck.deal(shoe, hand)
      end

    %{table | shoe: new_shoe, positions: positions |> Map.put(player_id, new_hand)}
  end

  def bet(%__MODULE__{bets: bets} = table, player, amount)
      when is_atom(player) and is_number(amount) do
    %{
      table
      | bets: bets |> Bets.player_bet(player, amount)
    }
  end

  def maybe_card_to(%__MODULE__{dealer: dealer_hand} = table, :dealer) do
    cond do
      dealer_hand.value < 17 ->
        table |> deal_card_to(:dealer)

      true ->
        table
    end
  end

  def maybe_card_to(%__MODULE__{positions: positions} = table, %Blackjack.Player{} = player) do
    p = Surefire.Player.id(player)

    %Blackjack.Player.PlayCommand{id: ^p, command: act} =
      Blackjack.Player.hit_or_stand(
        player,
        positions[p].value
      )

    # TODO :  a more clean/formal way to requesting from player,
    #    and player confirming action (to track for replays...)
    case act do
      :stand -> table
      :hit -> table |> deal_card_to(p)
    end
  end

  @doc ~s"""
    deals the cards to all players once, then the dealer, then all players again.
  """
  def deal(%__MODULE__{bets: bets} = table) do
    player_ids = Bets.players(bets)

    (player_ids ++ [:dealer] ++ player_ids)
    |> Enum.reduce(table, fn
      p, t -> t |> deal_card_to(p)
    end)

    # TODO : check of bust or blackjack here already...
  end

  #  def play(%__MODULE__{positions: positions} = table, players) do
  #    # TODO: make sure somehow that all players who did bet have a hand.
  #    for p <- player_ids, reduce: {table, player_ids} do
  #      {table, next_players} ->
  #        if is_atom(positions[p].value) do
  #          # blackjack or bust: skip this... until resolve (???)
  #          {table, next_players |> List.delete(p)}
  #        else
  #          {table |> maybe_card_to(p), next_players}
  #        end
  #    end
  #
  #    # TODO : loop until the end of player turns
  #  end

  def play(%__MODULE__{} = table, :dealer) do
    cond do
      table.dealer.value < 17 ->
        # we recurse until value>=17
        table |> deal_card_to(:dealer) |> play(:dealer)

      # we let the table as is, resolution will be done in another place,
      # as it depends on other players as well...
      true ->
        table
    end
  end

  def resolve(%__MODULE__{positions: pos} = table, player) when is_atom(player) do
    # TODO : handle "push" when both are equal...
    hand_comp = Hand.compare(pos[player], table.dealer)
    # TODO : review actual cases (with tests) here
    if hand_comp == :gt do
      player_win(table, player)
    else
      player_lose(table, player)
    end
  end

  def player_win(%__MODULE__{bets: bets, positions: pos} = table, player)
      when is_atom(player) do
    {player_bet, bets} = bets |> Bets.player_end(player)

    {
      %{table | bets: bets, positions: pos |> Map.drop([player])},
      %Blackjack.Event.PlayerExit{id: player, gain: player_bet * 2}
    }
  end

  def player_lose(%__MODULE__{bets: bets, positions: pos} = table, player) when is_atom(player) do
    {_player_bet, bets} = bets |> Bets.player_end(player)

    {
      %{table | bets: bets, positions: pos |> Map.drop([player])},
      %Blackjack.Event.PlayerExit{id: player, gain: 0}
    }
  end
end
