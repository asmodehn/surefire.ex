defmodule LibertyBell do
  @moduledoc ~s"""
    # References:
    - http://slotgamedesign.com/2019/01/19/slot-math-tutorial-creating-par-sheets/
    - https://en.wikipedia.org/wiki/Liberty_Bell_(game)

    # Examples
    iex> LibertyBell.play |> IO.inspect |> LibertyBell.win


  """

  @bell :bell
  @horseshoe :horseshoe
  @spade :spade
  @diamond :diamond
  @heart :heart
  @star :star

  @reel_A [
    @bell,
    @horseshoe,
    @spade,
    @horseshoe,
    @diamond,
    @horseshoe,
    @spade,
    @horseshoe,
    @heart,
    @horseshoe
  ]

  @reel_B [
    @bell,
    @diamond,
    @star,
    @spade,
    @bell,
    @diamond,
    @heart,
    @star,
    @spade,
    @diamond
  ]

  @type event :: atom
  @type game_event :: event
  @type pay_event :: event

  @type bet :: pay_event
  @type result :: game_event
  @type payout :: pay_event

  @spec play(bet) :: result
  def play(_bet \\ 1) do
    {
      Enum.random(@reel_A),
      Enum.random(@reel_A),
      Enum.random(@reel_B)
    }
  end

  # TODO : here we want to extract the stochastic process on one side,
  # and the gamerules/payout table on the other,
  # because we want to expose the inner probabilities to the player as well.

  @spec win(result) :: payout
  def win({r1, r2, r3}) do
    case {r1, r2, r3} do
      {@bell, @bell, @bell} -> 20
      {@heart, @heart, @heart} -> 16
      {@diamond, @diamond, @diamond} -> 12
      {@spade, @spade, @spade} -> 8
      {@horseshoe, @horseshoe, @star} -> 4
      {@horseshoe, @horseshoe, _} -> 2
      _ -> 0
    end
  end
end
