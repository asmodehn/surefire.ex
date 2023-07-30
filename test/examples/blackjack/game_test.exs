defmodule Blackjack.GameTest do
  use ExUnit.Case, async: true

  alias Blackjack.Game

  describe "bet/3" do
    test "accepts the bet of a player" do
      game = Game.new() |> Game.bet(:bob, 45)

      # TODO :maybe this is one level too much ?
      assert game.bets == %Blackjack.Bets{bets: [bob: 45]}
    end
  end

  test "one-player game can go on until the end" do
    Game.new()
    |> IO.inspect()
    |> Game.bet(:alice, 12)
    |> IO.inspect()
    |> Game.deal()
    |> IO.inspect()
    |> Game.play(fn p, v -> %Blackjack.Player.PlayCommand{id: p, command: :stand} end)
    |> IO.inspect()
    |> Game.resolve()
    |> IO.inspect()
  end

  # TODO : more one-player game to test all possible situations...
end
