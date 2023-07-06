defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.Table

  import Blackjack.Deck, only: [deck: 0]

  test "new/0 creates a new Table with a shoe with 3 decks" do
    assert length(Table.new().shoe) == 3 * length(deck())
  end

  describe "deal_card/2" do
    test "can deal a card to the dealer" do
      table =
        Table.new()
        |> Table.next_card()
        # here we can see the table and the card
        |> IO.inspect()
        |> Table.card_to(:dealer)

      assert length(table.dealer) == 1
      assert %Blackjack.Deck.Card{} = List.first(table.dealer)
    end

    test "can deal a card to a player" do
      table =
        Table.new()
        |> Table.next_card()
        # here we can see the table and the card
        |> IO.inspect()
        |> Table.card_to(:bob)

      assert :bob in Map.keys(table.positions)
      assert length(table.positions[:bob]) == 1
      assert %Blackjack.Deck.Card{} = List.first(table.positions[:bob])
    end

    test "can deal a card to many players, including dealer" do
      table =
        [:alice, :bob, :dealer]
        |> Enum.reduce(Table.new(), fn
          p, t -> Table.next_card(t) |> Table.card_to(p)
        end)

      assert :alice in Map.keys(table.positions)
      assert :bob in Map.keys(table.positions)

      assert length(table.dealer) == 1
      assert length(table.positions[:alice]) == 1
      assert length(table.positions[:bob]) == 1

      assert %Blackjack.Deck.Card{} = List.first(table.dealer)
      assert %Blackjack.Deck.Card{} = List.first(table.positions[:alice])
      assert %Blackjack.Deck.Card{} = List.first(table.positions[:bob])
    end
  end
end
