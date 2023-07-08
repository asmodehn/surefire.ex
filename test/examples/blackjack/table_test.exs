defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Table, Hand, Deck.Card}

  import Blackjack.Deck, only: [deck: 0]

  test "new/0 creates a new Table with a shoe with 3 decks" do
    assert length(Table.new().shoe) == 3 * length(deck())
  end

  describe "next_card/1 |> card_to/2" do
    test "can deal a card to the dealer" do
      table =
        Table.new()
        |> Table.next_card()
        # here we can see the table and the card
        #        |> IO.inspect()
        |> Table.card_to(:dealer)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1
    end

    test "can deal a card to a player" do
      table =
        Table.new()
        |> Table.next_card()
        # here we can see the table and the card
        |> IO.inspect()
        |> Table.card_to(:bob)

      #        |> IO.inspect()

      assert :bob in Map.keys(table.positions)
      %Blackjack.Hand{cards: clist} = table.positions[:bob]
      assert length(clist) == 1
    end

    test "can deal a card to many players, including dealer" do
      table =
        [:alice, :bob, :dealer]
        |> Enum.reduce(Table.new(), fn
          p, t ->
            Table.next_card(t)
            #                  |> IO.inspect()
            |> Table.card_to(p)
        end)

      assert :alice in Map.keys(table.positions)
      assert :bob in Map.keys(table.positions)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.positions[:alice]
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.positions[:bob]
      assert length(clist) == 1
    end
  end

  test "hand value increase correctly when giving cards to dealer" do
    table = Table.new()

    test_table_hit = Table.card_to({table, %Card{value: :nine, color: :hearts}}, :dealer)

    # 9
    assert test_table_hit.dealer.value == 9

    test_table_stand =
      Table.card_to({test_table_hit, %Card{value: :nine, color: :clubs}}, :dealer)

    # 9 + 9
    assert test_table_stand.dealer.value == 18

    test_table_blackjack =
      Table.card_to({test_table_stand, %Card{value: :three, color: :clubs}}, :dealer)

    # 9 + 9 +3
    assert test_table_blackjack.dealer.value == :blackjack

    test_table_bust =
      Table.card_to(
        {test_table_blackjack, %Card{value: :five, color: :spades}},
        :dealer
      )

    # 9 + 9 +3 + 5
    assert test_table_bust.dealer.value == :bust
  end

  test "hand value increase correctly when giving cards to the player" do
    # TODO : we should only need table for this !
    table = Table.new()

    test_table_hit =
      Table.card_to(
        {table, %Card{value: :nine, color: :hearts}},
        :alice
      )

    # 9
    assert test_table_hit.positions[:alice].value == 9

    test_table_stand =
      Table.card_to(
        {test_table_hit, %Card{value: :nine, color: :clubs}},
        :alice
      )

    # 9 + 9
    assert test_table_stand.positions[:alice].value == 18

    test_table_blackjack =
      Table.card_to(
        {test_table_stand, %Card{value: :three, color: :clubs}},
        :alice
      )

    # 9 + 9 +3

    assert test_table_blackjack.positions[:alice].value == :blackjack

    test_table_bust =
      Blackjack.Table.card_to(
        {test_table_blackjack, %Card{value: :five, color: :spades}},
        :alice
      )

    # 9 + 9 +3 + 5
    assert test_table_bust.positions[:alice].value == :bust
  end

  describe "deal/2 " do
    test "deals two cards to each player and one card to the dealer" do
      table = Table.new() |> Table.deal([:alice, :bob, :charlie])

      assert Hand.size(table.positions[:alice]) == 2
      assert Hand.size(table.positions[:bob]) == 2
      assert Hand.size(table.positions[:charlie]) == 2
      assert Hand.size(table.dealer) == 1
    end
  end
end
