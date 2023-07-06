defmodule Blackjack.Table do
  alias Blackjack.Hand

  import Blackjack.Deck, only: [deck: 0]

  @derive {Inspect, only: [:dealer, :positions]}
  defstruct shoe: [], dealer: [], positions: %{}

  def new(_decks \\ 3) do
    %__MODULE__{
      shoe: Enum.shuffle(deck()) ++ Enum.shuffle(deck()) ++ Enum.shuffle(deck())
    }
  end

  def next_card(%__MODULE__{} = table) do
    [card | shoe] = table.shoe
    # TODO : into a struct
    {table, card}
  end

  def card_to({%__MODULE__{} = table, card}, :dealer) do
    %{table | dealer: table.dealer ++ [card]}
  end

  def card_to({%__MODULE__{} = table, card}, player) do
    %{
      table
      | positions:
          Map.merge(
            table.positions,
            Map.new([{player, [card]}]),
            fn _k, l1, l2 -> l1 ++ l2 end
          )
    }
  end

  def check_value(%__MODULE__{} = table, :dealer) do
    dealer_position = table.dealer |> Hand.value()

    case dealer_position do
      :bust -> :bust
      :blackjack -> :blackjack
      v -> v
    end
  end

  def check_value(%__MODULE__{} = table, player) do
    player_position = table.positions[player] |> Hand.value()

    case player_position do
      :bust -> :bust
      :blackjack -> :blackjack
      v -> v
    end
  end

  def close_position(%__MODULE__{positions: pos} = table, player) do
    %{table | positions: pos |> Map.drop([player])}
  end
end
