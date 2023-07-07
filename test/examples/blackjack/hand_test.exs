defmodule Blackjack.HandTest do
  use ExUnit.Case, async: true

  alias Blackjack.Hand
  alias Blackjack.Deck.Card

  describe "new/1" do
    test "creates a hand with a list of card, and the value of the card" do
      card = %Card{value: :nine, color: :hearts}
      hand = Hand.new(card)

      assert hand.cards == [card]
      assert hand.value == 9
    end
  end

  describe "add_card/2" do
    test "adds a card to a preexisting hand, calculating the value of the hand" do
      card = %Card{value: :nine, color: :hearts}
      hand = Hand.new(card)

      second_card = %Card{value: :jack, color: :spades}
      new_hand = Hand.add_card(hand, second_card)

      assert new_hand.cards == [card, second_card]
      assert new_hand.value == 9 + 10
    end
  end
end
