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

    test "adds a card to a preexisting hand, setting value to :bust if it is the case" do
      card = %Card{value: :nine, color: :hearts}
      hand = Hand.new(card)

      second_card = %Card{value: :jack, color: :spades}
      new_hand = Hand.add_card(hand, second_card)

      crazy_hit = %Card{value: :queen, color: :clubs}
      bust_hand = Hand.add_card(new_hand, crazy_hit)

      assert bust_hand.cards == [card, second_card, crazy_hit]
      assert bust_hand.value == :bust
    end

    test "adds a card to a preexisting hand, setting value to :blackjack if it is the case" do
      card = %Card{value: :ace, color: :hearts}
      hand = Hand.new(card)

      second_card = %Card{value: :jack, color: :spades}
      new_hand = Hand.add_card(hand, second_card)

      assert new_hand.cards == [card, second_card]
      assert new_hand.value == :blackjack
    end
  end
end
