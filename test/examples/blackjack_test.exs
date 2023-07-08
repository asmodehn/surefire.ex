defmodule BlackjackTest do
  use ExUnit.Case, async: true

  alias Blackjack.Deck.Card

  test "one-player game can go on until the end" do
    player = Blackjack.Player.new_test("alice", 42)

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
