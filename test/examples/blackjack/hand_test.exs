defmodule Blackjack.HandTest do
  use ExUnit.Case, async: true

  alias Blackjack.Hand

  use Blackjack.Card.Sigil

  describe "new/0" do
    test "creates a hand with an empty list of card, and 0 value" do
      hand = Hand.new()

      assert hand.cards == []
      assert hand.value == 0
    end
  end

  describe "add_card/2" do
    test "adds a card to a preexisting hand, calculating the value of the hand" do
      card = ~C[9]h
      hand = Hand.new() |> Hand.add_card(card)

      second_card = ~C[J]s
      new_hand = Hand.add_card(hand, second_card)

      assert new_hand.cards == card ++ second_card
      assert new_hand.value == 9 + 10
    end

    test "adds a card to a preexisting hand, setting value to :bust if it is the case" do
      card = ~C[9]h
      hand = Hand.new() |> Hand.add_card(card)

      second_card = ~C[J]s
      new_hand = Hand.add_card(hand, second_card)

      crazy_hit = ~C[Q]c
      bust_hand = Hand.add_card(new_hand, crazy_hit)

      assert bust_hand.cards == card ++ second_card ++ crazy_hit
      assert bust_hand.value == :bust
    end

    test "adds a card to a preexisting hand, setting value to :blackjack if it is the case" do
      card = ~C[A]h
      hand = Hand.new() |> Hand.add_card(card)

      second_card = ~C[J]s
      new_hand = Hand.add_card(hand, second_card)

      assert new_hand.cards == card ++ second_card
      assert new_hand.value == :blackjack
    end
  end

  describe "compare/2" do
    test " <21 and :blackjack -> :lt" do
      hand_left = Hand.new() |> Hand.add_card(~C[3]h ++ ~C[J]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[A]d)

      assert Hand.compare(hand_left, hand_right) == :lt
    end

    test " <21 and :bust -> :gt" do
      hand_left =
        Hand.new()
        |> Hand.add_card(~C[3]h ++ ~C[J]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[9]d ++ ~C[8]c)

      assert Hand.compare(hand_left, hand_right) == :gt
    end

    test " A <21 and B<21 then A < B => :lt" do
      hand_left =
        Hand.new()
        |> Hand.add_card(~C[3]h ++ ~C[J]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[9]d)

      assert Hand.compare(hand_left, hand_right) == :lt
    end

    test " A <21 and B<21 then A == B => :eq" do
      hand_left =
        Hand.new()
        |> Hand.add_card(~C[9]h ++ ~C[J]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[9]d)

      assert Hand.compare(hand_left, hand_right) == :eq
    end

    test " A <21 and B <21 then A > B => :gt" do
      hand_left =
        Hand.new()
        |> Hand.add_card(~C[9]h ++ ~C[J]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[3]d)

      assert Hand.compare(hand_left, hand_right) == :gt
    end

    test " A :blackjack and B <21 => :gt" do
      hand_left =
        Hand.new()
        |> Hand.add_card(~C[A]h ++ ~C[J]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[3]d)

      assert Hand.compare(hand_left, hand_right) == :gt
    end

    test " A :bust and B <21  => :lt" do
      hand_left =
        Hand.new()
        |> Hand.add_card(~C[9]h ++ ~C[J, 8]c)

      hand_right =
        Hand.new()
        |> Hand.add_card(~C[Q]s ++ ~C[3]d)

      assert Hand.compare(hand_left, hand_right) == :lt
    end
  end
end
