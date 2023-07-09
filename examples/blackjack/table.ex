defmodule Blackjack.Table do
  alias Blackjack.Hand

  import Blackjack.Deck, only: [deck: 0]

  # TODO : rounds, one game after another, using the same shoe.
  @derive {Inspect, only: [:dealer, :positions]}
  defstruct shoe: [], dealer: %Hand{}, positions: %{}
  # TODO : clear up position & hand confusion...

  def new(_decks \\ 3) do
    %__MODULE__{
      shoe: Enum.shuffle(deck()) ++ Enum.shuffle(deck()) ++ Enum.shuffle(deck())
    }
  end

  def next_card(%__MODULE__{} = table) do
    [card | shoe] = table.shoe
    # TODO : into a struct ?(event-like)
    {%{table | shoe: shoe}, card}
  end

  def card_to({%__MODULE__{} = table, card}, :dealer) do
    %{
      table
      | dealer: Hand.add_card(table.dealer, card)
        #    |> IO.inspect()
    }
  end

  def card_to({%__MODULE__{} = table, card}, player) do
    %{
      table
      | positions:
          table.positions
          |> Map.update(
            player,
            Hand.new(card),
            fn player_hand -> player_hand |> Hand.add_card(card) end
          )
        #                   |> IO.inspect()
    }
  end

  # TODO : next_card and card_to maybe in another module (linked with shoe...)

  def maybe_card_to(%__MODULE__{dealer: dealer_hand} = table, :dealer) do
    cond do
      dealer_hand.value < 17 ->
        table |> next_card() |> card_to(:dealer)

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
      :hit -> table |> next_card() |> card_to(p)
    end
  end

  @doc ~s"""
    deals the cards to all players once, then the dealer, then all players again.
  """
  def deal(%__MODULE__{} = table, player_ids) do
    (player_ids ++ [:dealer] ++ player_ids)
    |> Enum.reduce(table, fn
      p, t -> next_card(t) |> card_to(p)
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
        table |> next_card() |> card_to(:dealer) |> play(:dealer)

      # we let the table as is, resolution will be done in another place,
      # as it depends on other players as well...
      true ->
        table
    end
  end

  def resolve(%__MODULE__{} = table, player) when is_atom(player) do
    # TODO : handle "push" when both are equal...
    hand_comp = Hand.compare(table.positions[player], table.dealer)
    # TODO : review actual cases (with tests) here
    if hand_comp == :gt do
      player_win(table, player)
    else
      player_lose(table, player)
    end
  end

  def player_win(%__MODULE__{} = table, player)
      when is_atom(player) do
    # TODO : move bets onto the table, like positions/hands...
    {
      table |> Table.close_position(player),
      # TODO : change with amount
      %Blackjack.Event.PlayerExit{id: player, gain: true}
    }
  end

  def player_lose(%__MODULE__{} = table, player) when is_atom(player) do
    {table |> Table.close_position(player), %Blackjack.Event.PlayerExit{id: player, gain: false}}
  end

  def close_position(%__MODULE__{positions: pos} = table, player) do
    %{table | positions: pos |> Map.drop([player])}
  end
end
