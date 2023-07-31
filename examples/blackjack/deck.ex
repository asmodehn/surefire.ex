defmodule Blackjack.Deck do
  @type card_value :: atom() | nil

  @type card_color :: atom() | nil

  @type card :: {card_value, card_color}

  alias Blackjack.Card

  defmacro deck() do
    Enum.zip(
      Card.values() |> List.duplicate(4) |> List.flatten(),
      Card.colors()
      |> Enum.map(fn
        c -> List.duplicate(c, length(Card.values()))
      end)
      |> List.flatten()
    )
    |> Enum.map(fn {v, c} -> %Card{value: v, color: c} end)
    #    |> IO.inspect()
    |> Macro.escape()
  end

  # TODO : better than macro : sigil to interpret cards from 2char strings (with comma for append) + generator...

  @spec deal(Enumerable.t(), Collectable.t()) :: {Collectable.t(), Enumerable.t()}
  @spec deal(Enumerable.t(), Collectable.t(), integer) :: {Collectable.t(), Enumerable.t()}
  def deal(a_deck, hand, amount \\ 1) when is_list(a_deck) do
    new_hand =
      a_deck
      |> Enum.take(amount)
      |> Enum.into(hand)

    {new_hand, a_deck |> Enum.drop(amount)}
  end
end
