defmodule Blackjack.TableTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Card, Table, Hand}

  use Blackjack.Card.Sigil

  test "new/1 creates a new Table with the shoe passed as parameter" do
    assert Table.new(Card.deck()).shoe == Card.deck()
  end

  describe "deal/2" do
    test "can deal a card from the shoe to the dealer" do
      table =
        Table.new(~C[4 6 8]h)
        |> Table.deal(:dealer)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert clist == ~C[4]h
    end

    test "can deal a card from the shoe to an atom player" do
      table =
        Table.new(~C[8 10 Q]s)
        |> Table.deal(:bob)

      assert :bob in Map.keys(table.players)
      %Blackjack.Hand{cards: clist} = table.players[:bob]
      assert clist == ~C[8]s
    end

    test "can deal a card from the shoe to a string player" do
      table =
        Table.new(~C[8 10 Q]s)
        |> Table.deal("Bob")

      assert "Bob" in Map.keys(table.players)
      %Blackjack.Hand{cards: clist} = table.players["Bob"]
      assert clist == ~C[8]s
    end

    test "can deal cards from the shoe to many atom players, including dealer" do
      table = Table.new(~C[3 7 J]c) |> Table.deal([:alice, :bob, :dealer])

      assert :alice in Map.keys(table.players)
      assert :bob in Map.keys(table.players)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.players[:alice]
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.players[:bob]
      assert length(clist) == 1
    end

    test "can deal cards from the shoe to many string players, and dealer" do
      table = Table.new(~C[3 7 J]c) |> Table.deal(["Alice", "Bob", :dealer])

      assert "Alice" in Map.keys(table.players)
      assert "Bob" in Map.keys(table.players)

      %Blackjack.Hand{cards: clist} = table.dealer
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.players["Alice"]
      assert length(clist) == 1

      %Blackjack.Hand{cards: clist} = table.players["Bob"]
      assert length(clist) == 1
    end
  end

  describe "deal/1 " do
    test "deals one card to each player (the dealer can be a player here)" do
      table =
        Table.new(~C[3 7 J]c)
        |> Table.deal([:alice, :bob, :dealer])

      assert Hand.size(table.players[:alice]) == 1
      assert Hand.size(table.players[:bob]) == 1
      assert Hand.size(table.dealer) == 1
    end
  end

  describe "play/3" do
    test "doesnt change player hand if hit and shoe is empty, and mark table result as void" do
      table = Table.new(~C[1 2 3]h) |> Table.deal([:bob, :dealer, :bob])

      updated_table = table |> Table.play(:bob, fn _ph, _dh -> :hit end)

      assert updated_table == %{table | result: :void}
    end

    test "doesnt change dealer hand if hit and shoe is empty, and mark table result as void" do
      table = Table.new(~C[1 2 3]h) |> Table.deal([:bob, :dealer, :bob])

      updated_table = table |> Table.play(:dealer, fn _h, _dh -> :hit end)

      assert updated_table == %{table | result: :void}
    end

    test "makes the dealer hit recursively while < 17" do
      table =
        Table.new(~C[A 2 3 4 5]h)
        |> Table.play(:dealer, fn
          h, dh -> Blackjack.Avatar.hit_or_stand(%Blackjack.Dealer{}, h, dh)
        end)

      assert table.dealer == Hand.new() |> Hand.add_card(~C[A 2 3 4]h)
    end

    test "allows a player to decide to stand or hit" do
      table =
        Table.new(Card.deck())
        |> Table.deal([:alice, "Bob", :charlie])

      # TODO : detemrinist test with known cards in shoe.
      # Currently test pass even if :bust or :blackjack
      same_table = Table.play(table, :alice, fn _hand_value, _dh -> :stand end)

      assert same_table.players[:alice].value == table.players[:alice].value

      updated_table = Table.play(same_table, "Bob", fn _hand_value, _dh -> :hit end)

      assert updated_table.players["Bob"].value >= same_table.players["Bob"].value

      final_table =
        Table.play(updated_table, :charlie, fn _hand_value, _dh -> Enum.random([:stand, :hit]) end)

      assert final_table.players[:charlie].value >= same_table.players[:charlie].value
    end

    test "decide :win or :lose for each player, after dealer plays" do
      table =
        Table.new(Card.deck())
        |> Table.deal([:alice, "Bob", :charlie, :dealer, :alice, "Bob", :charlie])
        |> Table.play(:alice, fn _hand_value, _dh -> Enum.random([:stand, :hit]) end)
        |> Table.play("Bob", fn _hand_value, _dh -> Enum.random([:stand, :hit]) end)
        |> Table.play(:charlie, fn _hand_value, _dh -> Enum.random([:stand, :hit]) end)
        |> Table.play(:dealer, fn hv, dh ->
          Blackjack.Avatar.hit_or_stand(%Blackjack.Dealer{}, hv, dh)
        end)

      assert table.dealer.value >= 17

      %Table{result: result} = table

      assert length(Map.keys(result)) == 3
      assert result[:alice] in [:win, :lose]
      assert result["Bob"] in [:win, :lose]
      assert result[:charlie] in [:win, :lose]
    end
  end

  describe "resolve/2" do
    test "decide :lose early if a player busts" do
      table =
        Table.new(~C[9 10 J]h)
        |> Table.deal([:bob, :bob, :bob])
        |> Table.resolve(:bob)

      assert table.players[:bob] == Hand.new() |> Hand.add_card(~C[9 10 J]h)
      assert table.players[:bob].value == :bust
      assert table.result == %{bob: :lose}
    end
  end
end
