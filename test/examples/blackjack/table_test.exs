defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Deck, Table, Hand}
  alias Blackjack.Player.PlayCommand

  test "new/1 creates a new Table with the shoe passed as parameter" do
    assert Table.new(Deck.new()).shoe == Deck.new()
  end

  describe "deal/2" do
    test "can deal a card to the dealer" do
      table =
        Table.new(Deck.new())
        |> Table.deal(:dealer)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1
    end

    test "can deal a card to a player" do
      table =
        Table.new(Deck.new())
        |> Table.deal(:bob)

      assert :bob in Map.keys(table.players)
      %Blackjack.Hand{cards: clist} = table.players[:bob]
      assert length(clist) == 1
    end

    test "can deal a card to many players, including dealer" do
      table =
        [:alice, :bob, :dealer]
        |> Enum.reduce(Table.new(Deck.new()), fn
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
        Table.new(Deck.new())
        |> Table.deal([:alice, :bob, :charlie])

      assert Hand.size(table.players[:alice]) == 2
      assert Hand.size(table.players[:bob]) == 2
      assert Hand.size(table.players[:charlie]) == 2
      assert Hand.size(table.dealer) == 1
    end
  end

  describe "play/3" do
    test "allows a player to decide to stand or hit" do
      table =
        Table.new(Deck.new())
        |> Table.deal([:alice, :bob, :charlie])

      # TODO : detemrinist test with known cards in shoe.
      # Currently test pass even if :bust or :blackjack
      same_table =
        Table.play(table, :alice, fn _hand_value -> %PlayCommand{id: :alice, command: :stand} end)

      assert same_table.players[:alice].value == table.players[:alice].value

      updated_table =
        Table.play(same_table, :bob, fn _hand_value -> %PlayCommand{id: :bob, command: :hit} end)

      assert updated_table.players[:bob].value >= same_table.players[:bob].value

      final_table =
        Table.play(updated_table, :charlie, fn _hand_value ->
          %PlayCommand{id: :charlie, command: Enum.random([:stand, :hit])}
        end)

      assert final_table.players[:charlie].value >= same_table.players[:charlie].value
    end
  end

  describe "resolve/1" do
    test "deals last cards to the dealer, and decide :win or :lose for each player" do
      table =
        Table.new(Deck.new())
        |> Table.deal([:alice, :bob, :charlie])

      final_table =
        table
        |> Table.play(:alice, fn _hand_value ->
          %PlayCommand{id: :alice, command: Enum.random([:stand, :hit])}
        end)
        |> Table.play(:bob, fn _hand_value ->
          %PlayCommand{id: :bob, command: Enum.random([:stand, :hit])}
        end)
        |> Table.play(:charlie, fn _hand_value ->
          %PlayCommand{id: :charlie, command: Enum.random([:stand, :hit])}
        end)

      {resolved_table, win_lose} = Table.resolve(final_table)

      assert resolved_table.dealer.value >= 17
      assert length(win_lose) == 3
      assert win_lose[:alice] in [:win, :lose]
      assert win_lose[:bob] in [:win, :lose]
      assert win_lose[:charlie] in [:win, :lose]
    end
  end
end
