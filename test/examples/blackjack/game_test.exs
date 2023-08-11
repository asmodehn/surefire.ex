defmodule Blackjack.GameTest do
  use ExUnit.Case, async: true

  alias Blackjack.Game

  @tag :current
  test "one-player game can go on until the end" do
    player =
      Blackjack.Player.Random.new("alice", 42)
      |> IO.inspect()

    bj = Game.new()
    with_bets = bj |> Game.bet(player, 21)
    round_done = with_bets |> Game.play()
    resolved = round_done |> Game.resolve() |> IO.inspect()

    round = resolved.rounds |> List.first()

    # We have a result for alice.
    assert :alice in Keyword.keys(round.table.result)

    # TODO : fix this !
    #    case round.table.result[:alice] do
    #      :lose -> assert resolved.players["alice"].account == 21
    #      :win -> assert resolved.players["alice"].account == 63
    ##      :tie -> # TODO
    #
    #    end
  end
end
