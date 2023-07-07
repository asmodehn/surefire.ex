defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.Table

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
end
