defmodule Blackjack.Table do
  alias Blackjack.Hand

  import Blackjack.Deck, only: [deck: 0]

  @derive {Inspect, only: [:dealer, :positions]}
  defstruct shoe: [], dealer: %Hand{}, positions: %{}

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

  def check_hand(%__MODULE__{} = table, :dealer) do
    cond do
      table.dealer.value > 21 -> :bust
      table.dealer.value == 21 -> :blackjack
      # dealer mandatory stand after 17 !!
      table.dealer.value >= 17 -> :stand
      true -> table.dealer.value
    end
  end

  def check_hand(%__MODULE__{} = table, player) do
    val = table.positions[player].value

    cond do
      val > 21 -> :bust
      val == 21 -> :blackjack
      true -> val
    end
  end

  def close_position(%__MODULE__{positions: pos} = table, player) do
    %{table | positions: pos |> Map.drop([player])}
  end
end
