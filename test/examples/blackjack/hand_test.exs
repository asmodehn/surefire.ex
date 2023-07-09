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

  describe "compare/2" do
    test " <21 and :blackjack -> :lt" do
      hand_left =
        Hand.new(%Card{value: :three, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :ace, color: :diamonds})

      assert Hand.compare(hand_left, hand_right) == :lt
    end

    test " <21 and :bust -> :gt" do
      hand_left =
        Hand.new(%Card{value: :three, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :nine, color: :diamonds})
        |> Hand.add_card(%Card{value: :eight, color: :clubs})

      assert Hand.compare(hand_left, hand_right) == :gt
    end

    test " A <21 and B<21 then A < B => :lt" do
      hand_left =
        Hand.new(%Card{value: :three, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :nine, color: :diamonds})

      assert Hand.compare(hand_left, hand_right) == :lt
    end

    test " A <21 and B<21 then A == B => :eq" do
      hand_left =
        Hand.new(%Card{value: :nine, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :nine, color: :diamonds})

      assert Hand.compare(hand_left, hand_right) == :eq
    end

    test " A <21 and B <21 then A > B => :gt" do
      hand_left =
        Hand.new(%Card{value: :nine, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :three, color: :diamonds})

      assert Hand.compare(hand_left, hand_right) == :gt
    end

    test " A :blackjack and B <21 => :gt" do
      hand_left =
        Hand.new(%Card{value: :ace, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :three, color: :diamonds})

      assert Hand.compare(hand_left, hand_right) == :gt
    end

    test " A :bust and B <21  => :lt" do
      hand_left =
        Hand.new(%Card{value: :nine, color: :hearts})
        |> Hand.add_card(%Card{value: :jack, color: :clubs})
        |> Hand.add_card(%Card{value: :eight, color: :clubs})

      hand_right =
        Hand.new(%Card{value: :queen, color: :spades})
        |> Hand.add_card(%Card{value: :three, color: :diamonds})

      assert Hand.compare(hand_left, hand_right) == :lt
    end
  end
end
