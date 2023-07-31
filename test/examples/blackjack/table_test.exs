defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Table, Hand}

  import Blackjack.Deck, only: [deck: 0]

  test "new/1 creates a new Table with the shoe passed as parameter" do
    assert Table.new(deck()).shoe == deck()
  end

  describe "deal/2" do
    test "can deal a card to the dealer" do
      table =
        Table.new(deck())
        |> Table.deal(:dealer)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1
    end

    test "can deal a card to a player" do
      table =
        Table.new(deck())
        |> Table.deal(:bob)

      assert :bob in Map.keys(table.players)
      %Blackjack.Hand{cards: clist} = table.players[:bob]
      assert length(clist) == 1
    end

    test "can deal a card to many players, including dealer" do
      table =
        [:alice, :bob, :dealer]
        |> Enum.reduce(Table.new(deck()), fn
          p, t -> t |> Table.deal(p)
        end)

      assert :alice in Map.keys(table.players)
      assert :bob in Map.keys(table.players)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.players[:alice]
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.players[:bob]
      assert length(clist) == 1
    end
  end

  describe "deal/1 " do
    test "deals two cards to each player and one card to the dealer" do
      table =
        Table.new(deck())
        |> Table.deal([:alice, :bob, :charlie])

      assert Hand.size(table.players[:alice]) == 2
      assert Hand.size(table.players[:bob]) == 2
      assert Hand.size(table.players[:charlie]) == 2
      assert Hand.size(table.dealer) == 1
    end
  end
end
