defmodule Monte do
  @moduledoc ~s"""
    # References:
    - https://en.wikipedia.org/wiki/Three-card_Monte

    # Examples
    iex> Monte.play |> IO.inspect |> Monte.win

  """

  @jclubs :jack_of_clubs
  @jspades :jack_of_spades
  @qhearts :queen_of_hearts

  @type event :: atom
  @type game_event :: event
  @type pay_event :: event

  @type bet :: pay_event
  @type result :: game_event
  @type payout :: pay_event

  @spec play(bet) :: result
  def play(bet \\ 1) do
    shuffled = Enum.shuffle([@jclubs, @jspades, @qhearts])

    # TODO : propose Opportunities to the player
    draw = Enum.random(0..2)

    {bet, Enum.at(shuffled, draw)}
  end

  @spec win({bet, result}) :: payout
  def win({bet, result}) do
    case result do
      @jclubs -> 0
      @jspades -> 0
      @qhearts -> bet * 2
    end
  end
end
