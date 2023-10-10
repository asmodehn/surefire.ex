defmodule Blackjack.RoundTest do
  use ExUnit.Case, async: true

  alias Blackjack.{Round, Hand, Card}

  alias Surefire.Accounting.{LedgerServer, LogServer, AccountID}

  use Blackjack.Card.Sigil

  # childspec for logserver, passing a name,
  # to not conflict with application's logserver.
  @logserver_spec %{
    id: LogServer,
    start: {LogServer, :start_link, [[], [name: :logserver_in_roundtest]]}
  }

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
      with history_pid <- start_supervised!(@logserver_spec),
           playerledger_pid <-
             start_supervised!(%{
               id: Player_LedgerServer,
               start: {LedgerServer, :start_link, [history_pid, [name: :player_ledger]]}
             }),
           gameledger_pid <-
             start_supervised!(%{
               id: Game_LedgerServer,
               start: {LedgerServer, :start_link, [history_pid, [name: :game_ledger]]}
             }) do
        # TODO : open assets and liabilities on all ledgers ?? or only in Game/Player modules ?
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
         %{
           playerledger_pid: playerledger_pid,
           gameledger_pid: gameledger_pid
         } do
      avatar =
        Surefire.Avatar.new(
          :bob,
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :assets
          },
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :avatar_test_round
          },
          100
        )
        |> Surefire.Avatar.automatize(:ask, fn _p ->
          "45"
          #          av, %AccountID{} = ra ->
          #            _tid = Surefire.Avatar.bet_transfer(av, 45, ra)
          #            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)

      _tid =
        LedgerServer.transfer_debit(
          gameledger_pid,
          "Transfer 1000 from game's assets to round",
          :assets,
          :test_round,
          1000
        )

      game =
        Round.new("test_round", Card.deck(), %AccountID{
          ledger_pid: gameledger_pid,
          account_id: :test_round
        })
        |> Round.enter(avatar)

      # TODO : verify transaction exists

      assert game.bets == %{bob: [%Surefire.Bets.Stake{holder: :bob, amount: 45}]}

      assert game.avatars == %{bob: avatar}
    end

    test "accepts the avatar and request a fake bet, without transaction" do
      avatar =
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

      game =
        Round.new(
          "test_round",
          Card.deck()
        )
        |> Round.enter(avatar)

      assert game.bets == %{bob: [%Surefire.Bets.Stake{holder: :bob, amount: 45}]}

      assert game.avatars == %{bob: avatar}
    end
  end

  describe "deal/2" do
    setup do
      with history_pid <- start_supervised!(@logserver_spec),
           playerledger_pid <-
             start_supervised!(%{
               id: Player_LedgerServer,
               start: {LedgerServer, :start_link, [history_pid, [name: :player_ledger]]}
             }),
           gameledger_pid <-
             start_supervised!(%{
               id: Game_LedgerServer,
               start: {LedgerServer, :start_link, [history_pid, [name: :game_ledger]]}
             }) do
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
      avatar =
        Surefire.Avatar.new(
          :bob,
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :assets
          },
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :bob
          },
          100
        )
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

      #        |> Surefire.Avatar.automatize(bet_transfer)
      #          av, %AccountID{} = ra ->
      #            _tid = Surefire.Avatar.bet_transfer(av, 45, ra)
      #            {45, av}
      #        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)

      _tid =
        LedgerServer.transfer_debit(
          gameledger_pid,
          "Transfer 1000 from game's assets to round",
          :assets,
          :test_round,
          1000
        )

      game =
        Round.new("test_round", [], %AccountID{
          ledger_pid: gameledger_pid,
          account_id: :test_round
        })
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
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

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
      avatar =
        Surefire.Avatar.new(
          :bob,
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :assets
          },
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :bob
          },
          100
        )
        |> Surefire.Avatar.automatize(:ask, fn _p ->
          "45"
          #          av, %AccountID{} = ra ->
          #            _tid = Surefire.Avatar.bet_transfer(av, 45, ra)
          #            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)

      _tid =
        LedgerServer.transfer_debit(
          gameledger_pid,
          "Transfer 1000 from game's assets to round",
          :assets,
          :test_round,
          1000
        )

      game =
        Round.new("test_round", ~C[5 8 K]h, %AccountID{
          ledger_pid: gameledger_pid,
          account_id: :test_round
        })
        |> Round.enter(avatar)
        |> Round.deal(:bob)

      # TODO : hand as just a list of cards (no struct) ???
      assert game.table.players == %{bob: Hand.new() |> Hand.add_card(~C[5]h)}
      # cards left in shoe
      assert game.table.shoe == ~C[8 K]h
    end

    test "deals card to a player with a bet without ledgers" do
      avatar =
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

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
      avatar =
        Surefire.Avatar.new(
          :bob,
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :assets
          },
          %AccountID{
            ledger_pid: playerledger_pid,
            account_id: :bob
          },
          100
        )
        |> Surefire.Avatar.automatize(:ask, fn _p ->
          "45"
          #          av, %AccountID{} = ra ->
          #            _tid = Surefire.Avatar.bet_transfer(av, 45, ra)
          #            {45, av}
        end)

      :ok = LedgerServer.open_account(gameledger_pid, :test_round, "Test Round Account", :debit)

      _tid =
        LedgerServer.transfer_debit(
          gameledger_pid,
          "Transfer 1000 from game's assets to round",
          :assets,
          :test_round,
          1000
        )

      game =
        Round.new("test_round", ~C[5 8 K]h, %AccountID{
          ledger_pid: gameledger_pid,
          account_id: :test_round
        })
        |> Round.enter(avatar)
        |> Round.deal(:alice)

      assert game.table.players == %{}
      # cards left in shoe
      assert game.table.shoe == ~C[5 8 K]h
    end

    test "deals no card to a player without a bet, without ledgers" do
      avatar =
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

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

    # TODO
    #    test "pass the game state to the decision process"

    test "triggers a choice to hit or stand" do
      bob_decision = fn
        _prompt, choice -> raise "bob needs to decide #{choice |> Map.values() |> inspect()}"
      end

      avatar =
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)
        |> Surefire.Avatar.automatize(:decide, bob_decision)

      game =
        Round.new("test_round", ~C[5 8 K]h)
        |> Round.enter(avatar)
        |> Round.deal()

      assert_raise RuntimeError, "bob needs to decide [:stand, :hit]", fn ->
        game |> Round.play(:bob)
      end
    end

    test "dealer play is stand on 17, hit otherwise" do
      game =
        Round.new("test_round", ~C[7 K]h)
        # Note: only dealer playing with himself
        |> Round.deal()

      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[7]h)

      updated_game = game |> Round.play(:dealer)

      # hit
      assert updated_game.table.dealer == Hand.new() |> Hand.add_card(~C[7 K]h)

      same_game = updated_game |> Round.play(:dealer)

      # stand
      assert same_game.table.dealer == Hand.new() |> Hand.add_card(~C[7 K]h)
    end
  end

  describe "resolve" do
    test "decides if a player wins and update bets" do
      avatar =
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

      game =
        Round.new("test_round", ~C[A 8 K]h ++ ~C[A]s)
        |> Round.enter(avatar)
        # CAREFUL : Round.deal deals one card to each player in list, then dealer, then players again
        |> Round.deal([:bob])

      # blackjack
      assert game.table.players[:bob] == Hand.new() |> Hand.add_card(~C[A K]h)
      # only one card at this stage
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[8]h)

      # dealer must hit once !
      dealt_game = game |> Round.play(:dealer)
      # 21 >= 19 >= 17
      assert dealt_game.table.dealer == Hand.new() |> Hand.add_card(~C[8]h ++ ~C[A]s)

      resolved_game = dealt_game |> Round.resolve()

      # winnings in bets: double
      assert resolved_game.bets == %{bob: [%Surefire.Bets.Stake{holder: :bob, amount: 90}]}
    end

    test "decides if a player loses and update bets" do
      avatar =
        Surefire.Avatar.new(:bob)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "45" end)

      game =
        Round.new("test_round", ~C[5 J K A]h)
        |> Round.enter(avatar)
        |> Round.deal([:bob])

      # 15
      assert game.table.players[:bob] == Hand.new() |> Hand.add_card(~C[5 K]h)
      # blackjack
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[J]h)

      # dealer must hit once !
      dealt_game = game |> Round.play(:dealer)
      # blackjack
      assert dealt_game.table.dealer == Hand.new() |> Hand.add_card(~C[J A]h)

      resolved_game = dealt_game |> Round.resolve()

      # winnings in bet: none
      assert resolved_game.bets == %{bob: [%Surefire.Bets.Stake{holder: :bob, amount: 0}]}
    end
  end

  describe "one-player game" do
    test "can get blackjack on deal and win" do
      avatar =
        Surefire.Avatar.new(:alice)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "12" end)
        |> Surefire.Avatar.automatize(:decide, fn _p, _c -> :stand end)

      game =
        Round.new("test_round", ~C[J]h ++ ~C[8]s ++ ~C[A]c ++ ~C[8 K]d)
        |> Round.enter(avatar)
        |> Round.deal()

      assert game.table.players[:alice] == Hand.new() |> Hand.add_card(~C[J]h ++ ~C[A]c)
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[8]s)

      # TODO : win should already be decided before play is called !
      finished_game =
        game
        |> Round.play()
        |> Round.play(:dealer)
        |> Round.resolve()

      #      |> IO.inspect()

      assert finished_game.table.dealer == Hand.new() |> Hand.add_card(~C[8]s ++ ~C[8 K]d)

      assert finished_game.table.result == %{alice: :win}
    end

    test "can get blackjack on deal and lose (WIP should tie)" do
      avatar =
        Surefire.Avatar.new(:alice)
        |> Surefire.Avatar.automatize(:ask, fn _p -> "12" end)
        |> Surefire.Avatar.automatize(:decide, fn _p, _c -> :stand end)

      game =
        Round.new("test_round", ~C[J]h ++ ~C[A]s ++ ~C[A]c ++ ~C[Q]d)
        |> Round.enter(avatar)
        |> Round.deal()

      assert game.table.players[:alice] == Hand.new() |> Hand.add_card(~C[J]h ++ ~C[A]c)
      assert game.table.dealer == Hand.new() |> Hand.add_card(~C[A]s)

      # TODO : win should already be decided before play is called !
      finished_game =
        game
        |> Round.play()
        |> Round.play(:dealer)
        |> Round.resolve()

      #      |> IO.inspect()

      assert finished_game.table.dealer == Hand.new() |> Hand.add_card(~C[A]s ++ ~C[Q]d)
      # TODO : should be tie / push / standoff
      assert finished_game.table.result == %{alice: :lose}
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
