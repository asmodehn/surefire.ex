defmodule Blackjack.Deck do
  @type card_value :: atom() | nil

  @type card_color :: atom() | nil

  @type card :: {card_value, card_color}

  use Blackjack.Card

  def new() do
    ~C[2 3 4 5 6 7 8 9 10 J Q K A]h ++
      ~C[2 3 4 5 6 7 8 9 10 J Q K A]s ++
      ~C[2 3 4 5 6 7 8 9 10 J Q K A]c ++
      ~C[2 3 4 5 6 7 8 9 10 J Q K A]d
  end

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
