defmodule Blackjack.BetsTest do
  use ExUnit.Case, async: true

  alias Blackjack.Bets

  test "player_bet/3 adds a bet for this player" do
    assert %Bets{bets: [alice: 1, bob: 2]}
           |> Bets.player_bet(:alice, 3) == %Bets{bets: [alice: 4, bob: 2]}
  end
end

defmodule BlackjackTest do
  use ExUnit.Case, async: true

  alias Blackjack.Deck.Card

  test "check_positions check the position of the dealer" do
    player = Surefire.TestPlayer.new("alice", 42)

    # TODO : we should only need table for this !
    bj = Blackjack.new([player])

    test_table_hit =
      Blackjack.Table.card_to({bj.table, %Card{value: :nine, color: :hearts}}, :dealer)

    # 9
    assert Blackjack.check_positions(%{bj | table: test_table_hit}, :dealer) == :hit

    test_table_stand =
      Blackjack.Table.card_to({test_table_hit, %Card{value: :nine, color: :clubs}}, :dealer)

    # 9 + 9
    assert Blackjack.check_positions(%{bj | table: test_table_stand}, :dealer) == :stand

    test_table_blackjack =
      Blackjack.Table.card_to({test_table_stand, %Card{value: :three, color: :clubs}}, :dealer)

    # 9 + 9 +3
    assert Blackjack.check_positions(%{bj | table: test_table_blackjack}, :dealer) == :blackjack

    test_table_bust =
      Blackjack.Table.card_to(
        {test_table_blackjack, %Card{value: :five, color: :spades}},
        :dealer
      )

    # 9 + 9 +3 + 5
    assert Blackjack.check_positions(%{bj | table: test_table_bust}, :dealer) == :bust
  end

  test "check_positions check the position of the player" do
    player = Surefire.TestPlayer.new("alice", 42)

    # TODO : we should only need table for this !
    bj = Blackjack.new([player])

    test_table_hit =
      Blackjack.Table.card_to(
        {bj.table, %Card{value: :nine, color: :hearts}},
        Surefire.Player.id(player)
      )

    # 9
    assert Blackjack.check_positions(%{bj | table: test_table_hit}, Surefire.Player.id(player)) in [
             :hit,
             :stand
           ]

    test_table_stand =
      Blackjack.Table.card_to(
        {test_table_hit, %Card{value: :nine, color: :clubs}},
        Surefire.Player.id(player)
      )

    # 9 + 9
    assert Blackjack.check_positions(%{bj | table: test_table_stand}, Surefire.Player.id(player)) in [
             :hit,
             :stand
           ]

    test_table_blackjack =
      Blackjack.Table.card_to(
        {test_table_stand, %Card{value: :three, color: :clubs}},
        Surefire.Player.id(player)
      )

    # 9 + 9 +3
    assert Blackjack.check_positions(
             %{bj | table: test_table_blackjack},
             Surefire.Player.id(player)
           ) == :blackjack

    test_table_bust =
      Blackjack.Table.card_to(
        {test_table_blackjack, %Card{value: :five, color: :spades}},
        Surefire.Player.id(player)
      )

    # 9 + 9 +3 + 5
    assert Blackjack.check_positions(%{bj | table: test_table_bust}, Surefire.Player.id(player)) ==
             :bust
  end

  test "one-player game can go on until the end" do
    player = Surefire.TestPlayer.new("alice", 42)

    Blackjack.new([player])
    |> IO.inspect()
    |> Blackjack.bet(Surefire.Player.id(player), 12)
    |> IO.inspect()
    |> Blackjack.deal()
    |> IO.inspect()
    |> Blackjack.play()
    |> IO.inspect()
    |> Blackjack.resolve()
    |> IO.inspect()
  end
end
