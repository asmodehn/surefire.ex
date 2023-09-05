defmodule Blackjack.RoundTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Round, Hand, Card}

  alias Surefire.Accounting.{LedgerServer, LogServer}

  use Blackjack.Card.Sigil

  describe "new/1" do
    test "accepts an empty deck as the shoe" do
      game = Round.new("test_round", ~C[])
      assert game.table.shoe == ~C[]
    end

    test "accepts a deck of cards as the shoe" do
      game = Round.new("test_round", ~C[3 6 8 10 Q]c)
      assert game.table.shoe == ~C[3 6 8 10 Q]c
    end
  end

  describe "enter/3" do
    setup do
      with history_pid <- start_supervised!(LogServer),
           playerledger_pid <- start_supervised!({LedgerServer, history_pid}, id: :player_ledger),
           gameledger_pid <- start_supervised!({LedgerServer, history_pid}, id: :game_ledger) do
        # TODO : open assets and liablities on all ledgers ?? or only in Game/Player modules ?
        :ok = LedgerServer.open_account(playerledger_pid, :assets, "Assets", :debit)
        :ok = LedgerServer.open_account(gameledger_pid, :assets, "Assets", :debit)

        %{
          history_pid: history_pid,
          playerledger_pid: playerledger_pid,
          gameledger_pid: gameledger_pid
        }
      end
    end

    test "accepts the avatar and request a bet",
         %{playerledger_pid: playerledger_pid, gameledger_pid: gameledger_pid} do
      :ok =
        LedgerServer.open_account(playerledger_pid, :avatar_test_round, "Avatar Account", :debit)

      _tid = LedgerServer.transfer(playerledger_pid, :assets, :avatar_test_round, 100)

      _avatar_account =
        Surefire.Accounting.LedgerServer.view(playerledger_pid, :avatar_test_round)

      avatar =
        Surefire.Avatar.new(:bob, :from_test, playerledger_pid, :avatar_test_round)
        |> Surefire.Avatar.with_action(:bet, fn
          av, gl, ra ->
            _tid = Surefire.Avatar.bet_transfer(av, 45, gl, ra)
            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)
      _tid = LedgerServer.transfer(gameledger_pid, :assets, :test_round, 1000)

      game =
        Round.new("test_round", Card.deck(), gameledger_pid, :test_round)
        |> Round.enter(avatar)

      # TODO : verify transaction exists

      # TODO :maybe this is one level too much ? => integrate bets in avatar's account
      assert game.bets == %Blackjack.Bets{bets: [bob: 45]}
      assert game.avatars == %{bob: avatar}
    end

    test "accepts the avatar and request a fake bet, without transaction" do
      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)

      game =
        Round.new(
          "test_round",
          Card.deck()
        )
        |> Round.enter(avatar)

      # TODO :maybe this is one level too much ? => integrate bets in avatar's account
      assert game.bets == %Blackjack.Bets{bets: [bob: 45]}
      assert game.avatars == %{bob: avatar}
    end
  end

  describe "deal/2" do
    setup do
      with history_pid <- start_supervised!(LogServer),
           playerledger_pid <- start_supervised!({LedgerServer, history_pid}, id: :player_ledger),
           gameledger_pid <- start_supervised!({LedgerServer, history_pid}, id: :game_ledger) do
        # TODO : open assets and liablities on all ledgers ?? or only in Game/Player modules ?
        :ok = LedgerServer.open_account(playerledger_pid, :assets, "Assets", :debit)
        :ok = LedgerServer.open_account(gameledger_pid, :assets, "Assets", :debit)

        %{
          history_pid: history_pid,
          playerledger_pid: playerledger_pid,
          gameledger_pid: gameledger_pid
        }
      end
    end

    test "deals no card when shoe is empty and mark table as void",
         %{playerledger_pid: playerledger_pid, gameledger_pid: gameledger_pid} do
      :ok = LedgerServer.open_account(playerledger_pid, :bob, "Avatar Bob Account", :debit)
      _tid = LedgerServer.transfer(playerledger_pid, :assets, :bob, 100)

      avatar =
        Surefire.Avatar.new(:bob, :from_test, playerledger_pid, :bob)
        |> Surefire.Avatar.with_action(:bet, fn
          av, gl, ra ->
            _tid = Surefire.Avatar.bet_transfer(av, 45, gl, ra)
            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)
      _tid = LedgerServer.transfer(gameledger_pid, :assets, :test_round, 1000)

      game =
        Round.new("test_round", [], gameledger_pid, :test_round)
        |> Round.enter(avatar)
        |> Round.deal(:bob)

      # TODO : verify transaction exists

      # TODO : hand as just a list of cards (no struct) ???
      # => bob has no hand
      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[]
      assert game.table.result == :void
    end

    test "deals no card when shoe is empty and mark table as void without ledgers" do
      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)

      game =
        Round.new("test_round", [])
        |> Round.enter(avatar)
        |> Round.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      # => bob has no hand
      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[]
      assert game.table.result == :void
    end

    test "deals card to a player with a bet",
         %{playerledger_pid: playerledger_pid, gameledger_pid: gameledger_pid} do
      :ok = LedgerServer.open_account(playerledger_pid, :bob, "Avatar Bob Account", :debit)
      _tid = LedgerServer.transfer(playerledger_pid, :assets, :bob, 100)

      avatar =
        Surefire.Avatar.new(:bob, :from_test, playerledger_pid, :bob)
        |> Surefire.Avatar.with_action(:bet, fn
          av, gl, ra ->
            _tid = Surefire.Avatar.bet_transfer(av, 45, gl, ra)
            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)
      _tid = LedgerServer.transfer(gameledger_pid, :assets, :test_round, 1000)

      game =
        Round.new("test_round", ~C[5 8 K]h, gameledger_pid, :test_round)
        |> Round.enter(avatar)
        |> Round.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      assert game.table.players == %{bob: Hand.new() |> Hand.add_card(~C[5]h)}
      # cards left in shoe
      assert game.table.shoe == ~C[8 K]h
    end

    test "deals card to a player with a bet without ledgers" do
      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)

      game =
        Round.new("test_round", ~C[5 8 K]h)
        |> Round.enter(avatar)
        |> Round.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      assert game.table.players == %{bob: Hand.new() |> Hand.add_card(~C[5]h)}
      # cards left in shoe
      assert game.table.shoe == ~C[8 K]h
    end

    test "deals no card to a player without a bet",
         %{playerledger_pid: playerledger_pid, gameledger_pid: gameledger_pid} do
      :ok = LedgerServer.open_account(playerledger_pid, :bob, "Avatar Bob Account", :debit)
      _tid = LedgerServer.transfer(playerledger_pid, :assets, :bob, 100)

      avatar =
        Surefire.Avatar.new(:bob, :from_test, playerledger_pid, :bob)
        |> Surefire.Avatar.with_action(:bet, fn
          av, gl, ra ->
            _tid = Surefire.Avatar.bet_transfer(av, 45, gl, ra)
            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)
      _tid = LedgerServer.transfer(gameledger_pid, :assets, :test_round, 1000)

      game =
        Round.new("test_round", ~C[5 8 K]h, gameledger_pid, :test_round)
        |> Round.enter(avatar)
        |> Round.deal(:alice)

      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[5 8 K]h
    end

    test "deals no card to a player without a bet, without ledgers" do
      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)

      game =
        Round.new("test_round", ~C[5 8 K]h)
        |> Round.enter(avatar)
        |> Round.deal(:alice)

      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[5 8 K]h
    end
  end

  describe "play/2" do
    # TODO : transactions here when "double" or "split"
    test "calls player_request with player hand and dealer hand" do
      bob_request = fn
        ph, dh -> raise "player_hand: #{ph}, dealer_hand: #{dh}"
      end

      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)
        |> Surefire.Avatar.with_action(:hit_or_stand, bob_request)

      game =
        Round.new("test_round", ~C[5 8 K]h)
        |> Round.enter(avatar)
        |> Round.deal()

      assert_raise RuntimeError, "player_hand: 5♥,K♥: 15, dealer_hand: 8♥: 8", fn ->
        game |> Round.play(:bob)
      end
    end
  end

  describe "resolve" do
    test "decides if a player wins and update bets" do
      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)

      game =
        Round.new("test_round", ~C[A 8 K]h ++ ~C[A]s)
        |> Round.enter(avatar)
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
      avatar =
        Surefire.Avatar.new(:bob, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {45, av} end)

      game =
        Round.new("test_round", ~C[5 J K A]h)
        |> Round.enter(avatar)
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
    test "can get blackjack on deal and win" do
      avatar =
        Surefire.Avatar.new(:alice, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {12, av} end)
        |> Surefire.Avatar.with_action(:hit_or_stand, fn _ph, _dh -> :stand end)

      game =
        Round.new("test_round", ~C[J]h ++ ~C[8]s ++ ~C[A]c ++ ~C[8 K]d)
        |> Round.enter(avatar)
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

    test "can get blackjack on deal and lose (WIP should tie)" do
      avatar =
        Surefire.Avatar.new(:alice, :from_test)
        |> Surefire.Avatar.with_action(:bet, fn av -> {12, av} end)
        |> Surefire.Avatar.with_action(:hit_or_stand, fn _ph, _dh -> :stand end)

      game =
        Round.new("test_round", ~C[J]h ++ ~C[A]s ++ ~C[A]c ++ ~C[Q]d)
        |> Round.enter(avatar)
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
