defmodule Blackjack.BetsTest do
  use ExUnit.Case, async: true

  alias Blackjack.Bets

  test "player_bet/3 adds a bet for this player" do
    assert %Bets{bets: [alice: 1, bob: 2]}
           |> Bets.player_bet(:alice, 3) == %Bets{bets: [alice: 4, bob: 2]}
  end
end
