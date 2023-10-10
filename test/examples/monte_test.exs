defmodule MonteTest do
  use ExUnit.Case, async: true

  # TODO :  replace this with same cards as blackjack...
  @jclubs :jack_of_clubs
  @jspades :jack_of_spades
  @qhearts :queen_of_hearts

  describe "new/2" do
    test "creates a Monte struct with cards" do
      assert Monte.new(:test_game) == %Monte{id: :test_game, cards: [@jclubs, @jspades, @qhearts]}
    end
  end

  describe "shuffle" do
    test "shuffles the cards randomly" do
      %Monte{id: :test_game, cards: cards} = Monte.new(:test_game) |> Monte.shuffle()
      assert @jclubs in cards
      assert @jspades in cards
      assert @qhearts in cards
    end
  end

  describe "add_player" do
    test "adds an avatar to the list of players" do
      avatar = Surefire.Avatar.new(:test_avatar)

      %Monte{id: :test_game, players: players} =
        Monte.new(:test_game)
        |> Monte.add_player(avatar)

      assert {:test_avatar, avatar} in players
    end
  end

  describe "bet" do
    test "request a bet on a position from the player" do
      avatar = Surefire.Avatar.new(:test_avatar)

      # automating the avatar for this test...
      # TODO : better way ??
      automated_avatar =
        avatar
        |> Surefire.Avatar.automatize(:decide, fn
          _prompt, choice_map -> 0
        end)
        |> Surefire.Avatar.automatize(:ask, fn
          _prompt -> "42"
        end)

      %Monte{id: :test_game, bets: stakes} =
        Monte.new(:test_game)
        |> Monte.add_player(automated_avatar)
        |> Monte.bet(automated_avatar)

      assert is_map(stakes)
      assert map_size(stakes) == 1
      assert stakes[0] == [%Surefire.Bets.Stake{holder: :test_avatar, amount: 42}]
    end
  end

  describe "reveal" do
    test "add wins for the player if the queen was found" do
      avatar = Surefire.Avatar.new(:test_avatar)

      # automating the avatar for this test...
      # TODO : better way ??
      automated_avatar =
        avatar
        |> Surefire.Avatar.automatize(:decide, fn
          _prompt, _choice_map -> 2
        end)
        |> Surefire.Avatar.automatize(:ask, fn
          _prompt -> "42"
        end)

      %Monte{id: :test_game, bets: wins} =
        Monte.new(:test_game)
        |> Monte.add_player(automated_avatar)
        |> Monte.bet(automated_avatar)
        |> Monte.reveal()

      assert is_map(wins)
      assert map_size(wins) == 1
      assert wins[2] == [%Surefire.Bets.Stake{holder: :test_avatar, amount: 42 * 2}]
    end

    test "does not record a win for the player if the queen was not found" do
      avatar = Surefire.Avatar.new(:test_avatar)

      # automating the avatar for this test...
      # TODO : better way ??
      automated_avatar =
        avatar
        |> Surefire.Avatar.automatize(:decide, fn
          _prompt, _choice_map -> 1
        end)
        |> Surefire.Avatar.automatize(:ask, fn
          _prompt -> "42"
        end)

      %Monte{id: :test_game, bets: wins} =
        Monte.new(:test_game)
        |> Monte.add_player(automated_avatar)
        |> Monte.bet(automated_avatar)
        |> Monte.reveal()

      assert wins[1] == nil
    end
  end
end
