defmodule Blackjack.GameTest do
  use ExUnit.Case, async: true

  alias Blackjack.Game

  @tag skip: true
  test "one-player game can go on until the end" do
    player = Surefire.TestPlayer.new("alice", 42)
    #      |> IO.inspect()

    {avatar, _updated_player} = player |> Surefire.TestPlayer.avatar("one_round")

    avatar =
      avatar
      |> Surefire.Avatar.with_action(:hit_or_stand, fn _ph, _dh -> Enum.random([:hit, :stand]) end)

    # TODO : review API here to decide how to play the long game with player/avatars...
    bj = Game.new()
    with_bets = bj |> Game.bet(avatar, 21)
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
