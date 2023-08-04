defmodule BlackjackTest do
  use ExUnit.Case, async: true

  @tag skip: true
  test "one-player game can go on until the end" do
    player = Blackjack.Player.new_test("alice", 42)

    Blackjack.new()
    |> IO.inspect()
    |> Blackjack.bet(player, 21)
    |> IO.inspect()
    |> Blackjack.play()
    |> IO.inspect()
    |> Blackjack.resolve()
    |> IO.inspect()
  end
end
