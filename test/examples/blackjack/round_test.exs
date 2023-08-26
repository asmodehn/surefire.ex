defmodule Blackjack.RoundTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Round, Hand}

  use Blackjack.Card.Sigil

  describe "new/1" do
    test "accepts an empty deck as the shoe" do
      game = Round.new(~C[])
      assert game.table.shoe == ~C[]
    end

    test "uses an empty deck as default shoe" do
      game = Round.new()
      assert game.table.shoe == ~C[]
    end

    test "accepts a deck of cards as the shoe" do
      game = Round.new(~C[3 6 8 10 Q]c)
      assert game.table.shoe == ~C[3 6 8 10 Q]c
    end
  end

  describe "bet/3" do
    test "accepts the bet of an avatar" do
      game = Round.new() |> Round.bet(Surefire.Avatar.new(:bob, :from_test), 45)

      # TODO :maybe this is one level too much ?
      assert game.bets == %Blackjack.Bets{bets: [bob: 45]}
      assert game.avatars == %{bob: Surefire.Avatar.new(:bob, :from_test)}
    end

    test "stores the avatar in the list for this round" do
      game = Round.new() |> Round.bet(Surefire.Avatar.new(:bob, :from_test), 45)

      # TODO :maybe this is one level too much ?
      assert game.bets == %Blackjack.Bets{bets: [bob: 45]}
      assert game.avatars == %{bob: Surefire.Avatar.new(:bob, :from_test)}
    end
  end

  describe "deal/2" do
    test "deals no card when shoe is empty and mark table as void" do
      game =
        Round.new()
        |> Round.bet(Surefire.Avatar.new(:bob, :from_test), 45)
        |> Round.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      # => bob has no hand
      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[]
      assert game.table.result == :void
    end

    test "deals card to a player with a bet" do
      game =
        Round.new(~C[5 8 K]h)
        |> Round.bet(Surefire.Avatar.new(:bob, :from_test), 45)
        |> Round.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      assert game.table.players == %{bob: Hand.new() |> Hand.add_card(~C[5]h)}
      # cards left in shoe
      assert game.table.shoe == ~C[8 K]h
    end

    test "deals no card to a player without a bet" do
      game =
        Round.new(~C[5 8 K]h)
        |> Round.bet(Surefire.Avatar.new(:alice, :from_test), 45)
        |> Round.deal(:bob)

      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[5 8 K]h
    end
  end

  describe "play/2" do
    test "calls player_request with player hand and dealer hand" do
      bob_request = fn
        ph, dh -> raise "player_hand: #{ph}, dealer_hand: #{dh}"
      end

      game =
        Round.new(~C[5 8 K]h)
        |> Round.bet(
          Surefire.Avatar.new(:bob, :from_test)
          |> Surefire.Avatar.with_action(:hit_or_stand, bob_request),
          45
        )
        |> Round.deal()

      assert_raise RuntimeError, "player_hand: 5♥,K♥: 15, dealer_hand: 8♥: 8", fn ->
        game |> Round.play(:bob)
      end
    end
  end

  describe "resolve" do
    test "decides if a player wins and update bets" do
      game =
        Round.new(~C[A 8 K]h ++ ~C[A]s)
        |> Round.bet(Surefire.Avatar.new(:bob, :from_test), 45)
        # CAREFUL : Round.deal deals one card to each player in list, then dealer, then players again
        |> Round.deal([:bob])

      # blackjack
      assert game.table.players[:bob] == Hand.new() |> Hand.add_card(~C[A K]h)
      # only one card at this stage
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[8]h)

      {resolved_game, [bob_exit]} = game |> Round.resolve()
      # 21 >= 19 >= 17
      assert resolved_game.table.dealer == Hand.new() |> Hand.add_card(~C[8]h ++ ~C[A]s)

      assert bob_exit == %Blackjack.Event.PlayerExit{id: :from_test, gain: 45 * 2}
      # bet is gone
      assert resolved_game.bets.bets == []
    end

    test "decides if a player loses and update bets" do
      game =
        Round.new(~C[5 J K A]h)
        |> Round.bet(Surefire.Avatar.new(:bob, :from_test), 45)
        |> Round.deal([:bob])

      # 15
      assert game.table.players[:bob] == Hand.new() |> Hand.add_card(~C[5 K]h)
      # blackjack
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[J]h)

      {resolved_game, [bob_exit]} = game |> Round.resolve()
      # blackjack
      assert resolved_game.table.dealer == Hand.new() |> Hand.add_card(~C[J A]h)

      assert bob_exit == %Blackjack.Event.PlayerExit{id: :from_test, gain: 0}
      # bet is gone
      assert resolved_game.bets.bets == []
    end
  end

  describe "one-player game" do
    @tag :current
    test "can get blackjack on deal and win" do
      game =
        Round.new(~C[J]h ++ ~C[8]s ++ ~C[A]c ++ ~C[8 K]d)
        |> Round.bet(
          Surefire.Avatar.new(:alice, :from_test)
          |> Surefire.Avatar.with_action(:hit_or_stand, fn _ph, _dh -> :stand end),
          12
        )
        |> Round.deal()

      assert game.table.players[:alice] == Hand.new() |> Hand.add_card(~C[J]h ++ ~C[A]c)
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[8]s)

      # TODO : win should already be decided before play is called !
      {finished_game, events} =
        game
        |> Round.play()
        |> Round.resolve()

      #      |> IO.inspect()

      assert finished_game.table.dealer == Hand.new() |> Hand.add_card(~C[8]s ++ ~C[8 K]d)

      assert finished_game.table.result == %{alice: :win}

      assert %Blackjack.Event.PlayerExit{id: :from_test, gain: 24} in events
    end

    @tag :current
    test "can get blackjack on deal and lose (WIP should tie)" do
      game =
        Round.new(~C[J]h ++ ~C[A]s ++ ~C[A]c ++ ~C[Q]d)
        |> Round.bet(
          Surefire.Avatar.new(:alice, :from_test)
          |> Surefire.Avatar.with_action(:hit_or_stand, fn _ph, _dh -> :stand end),
          12
        )
        |> Round.deal()

      assert game.table.players[:alice] == Hand.new() |> Hand.add_card(~C[J]h ++ ~C[A]c)
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[A]s)

      # TODO : win should already be decided before play is called !
      {finished_game, events} =
        game
        |> Round.play()
        |> Round.resolve()

      #      |> IO.inspect()

      assert finished_game.table.dealer == Hand.new() |> Hand.add_card(~C[A]s ++ ~C[Q]d)
      # TODO : should be tie / push / standoff
      assert finished_game.table.result == %{alice: :lose}

      assert %Blackjack.Event.PlayerExit{id: :from_test, gain: 0} in events
    end

    # TODO
    #    test "can hit and win"
    #
    #    test "can hit and bust"
    #
    #    test "can hit and lose"
    #
    #    test "can stand and lose"
    #
    #    test "can stand and win"

    # TODO : more one-player game to test all possible situations...
  end
end
