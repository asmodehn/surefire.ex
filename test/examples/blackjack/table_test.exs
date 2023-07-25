defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Table, Hand}

  import Blackjack.Deck, only: [deck: 0]

  test "new/0 creates a new Table with a shoe with 3 decks" do
    assert length(Table.new().shoe) == 3 * length(deck())
  end

  describe "deal_card_to/2" do
    test "can deal a card to the dealer" do
      table =
        Table.new()
        |> Table.deal_card_to(:dealer)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1
    end

    test "can deal a card to a player" do
      table =
        Table.new()
        |> Table.deal_card_to(:bob)

      assert :bob in Map.keys(table.positions)
      %Blackjack.Hand{cards: clist} = table.positions[:bob]
      assert length(clist) == 1
    end

    test "can deal a card to many players, including dealer" do
      table =
        [:alice, :bob, :dealer]
        |> Enum.reduce(Table.new(), fn
          p, t -> t |> Table.deal_card_to(p)
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

  describe "bet/3" do
    test "accepts the bet of a player" do
      table = Table.new() |> Table.bet(:bob, 45)

      # TODO :maybe this is one level too much ?
      assert table.bets == %Blackjack.Bets{bets: [bob: 45]}
    end
  end

  describe "deal/1 " do
    test "deals two cards to each player and one card to the dealer" do
      table =
        Table.new()
        |> Table.bet(:alice, 12)
        |> Table.bet(:bob, 45)
        |> Table.bet(:charlie, 23)
        |> Table.deal()

      assert Hand.size(table.positions[:alice]) == 2
      assert Hand.size(table.positions[:bob]) == 2
      assert Hand.size(table.positions[:charlie]) == 2
      assert Hand.size(table.dealer) == 1
    end
  end
end
