defmodule Blackjack.GameTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Game, Hand}

  use Blackjack.Card.Sigil

  describe "new/1" do
    test "accepts an empty deck as the shoe" do
      game = Game.new(~C[])
      assert game.table.shoe == ~C[]
    end

    test "uses an empty deck as default shoe" do
      game = Game.new()
      assert game.table.shoe == ~C[]
    end

    test "accepts a deck of cards as the shoe" do
      game = Game.new(~C[3 6 8 10 Q]c)
      assert game.table.shoe == ~C[3 6 8 10 Q]c
    end
  end

  describe "bet/3" do
    test "accepts the bet of a player" do
      game = Game.new() |> Game.bet(:bob, 45)

      # TODO :maybe this is one level too much ?
      assert game.bets == %Blackjack.Bets{bets: [bob: 45]}
    end
  end

  describe "deal/2" do
    test "deals no card when shoe is empty and mark table as void" do
      game =
        Game.new()
        |> Game.bet(:bob, 45)
        |> Game.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      # => bob has no hand
      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[]
      assert game.table.result == :void
    end

    test "deals card to a player with a bet" do
      game =
        Game.new(~C[5 8 K]h)
        |> Game.bet(:bob, 45)
        |> Game.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      assert game.table.players == %{bob: Hand.new() |> Hand.add_card(~C[5]h)}
      # cards left in shoe
      assert game.table.shoe == ~C[8 K]h
    end

    test "deals no card to a player without a bet" do
      game =
        Game.new(~C[5 8 K]h)
        |> Game.bet(:alice, 45)
        |> Game.deal(:bob)

      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[5 8 K]h
    end
  end

  describe "play/3" do
    test "a player without any card cannot play" do
      game =
        Game.new(~C[5 8 K]h)
        |> Game.bet(:bob, 45)

      updated_game = game |> Game.play(nil, :bob)

      assert updated_game == game
    end

    test "calls player_request with player hand and dealer hand" do
      bob_request = fn
        ph, dh -> raise "player_hand: #{ph}, dealer_hand: #{dh}"
      end

      game =
        Game.new(~C[5 8 K]h)
        |> Game.bet(:bob, 45)
        |> Game.deal()

      assert_raise RuntimeError, "player_hand: 5♥,K♥: 15, dealer_hand: 8♥: 8", fn ->
        game |> Game.play(bob_request, :bob)
      end
    end
  end

  describe "resolve" do
    test "decides if a player wins and update bets" do
      game =
        Game.new(~C[A 8 K]h ++ ~C[A]s)
        |> Game.bet(:bob, 45)
        # CAREFUL : Game.deal deals one card to each player in list, then dealer, then players again
        |> Game.deal([:bob])

      # blackjack
      assert game.table.players[:bob] == Hand.new() |> Hand.add_card(~C[A K]h)
      # only one card at this stage
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[8]h)

      {resolved_game, [bob_exit]} = game |> Game.resolve()
      # 21 >= 19 >= 17
      assert resolved_game.table.dealer == Hand.new() |> Hand.add_card(~C[8]h ++ ~C[A]s)

      assert bob_exit == %Blackjack.Event.PlayerExit{id: :bob, gain: 45 * 2}
      # bet is gone
      assert resolved_game.bets.bets == []
    end

    test "decides if a player loses and update bets" do
      game =
        Game.new(~C[5 J K A]h)
        |> Game.bet(:bob, 45)
        |> Game.deal([:bob])

      # 15
      assert game.table.players[:bob] == Hand.new() |> Hand.add_card(~C[5 K]h)
      # blackjack
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[J]h)

      {resolved_game, [bob_exit]} = game |> Game.resolve()
      # blackjack
      assert resolved_game.table.dealer == Hand.new() |> Hand.add_card(~C[J A]h)

      assert bob_exit == %Blackjack.Event.PlayerExit{id: :bob, gain: 0}
      # bet is gone
      assert resolved_game.bets.bets == []
    end
  end

  @tag skip: true
  describe "one-player game" do
    test "can go on until the end" do
      game =
        Game.new(~C[]h ++ ~C[]s ++ ~C[]c ++ ~C[]d)
        |> Game.bet(:alice, 12)
        |> Game.deal()

      # TODO : assert hands

      game
      |> Game.play(fn ph, dh -> :stand end)
      |> IO.inspect()
      |> Game.resolve()
      |> IO.inspect()
    end

    # TODO : more one-player game to test all possible situations...
  end
end
