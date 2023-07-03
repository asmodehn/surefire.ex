defmodule Blackjack.Deck do
  @type card_value :: atom() | nil

  @type card_color :: atom() | nil

  @type card :: {card_value, card_color}

  defmodule Card do
    @two :two
    @three :three
    @four :four
    @five :five
    @six :six
    @seven :seven
    @eight :eight
    @nine :nine
    @ten :ten
    @jack :jack
    @queen :queen
    @king :king
    # also one !
    @ace :ace

    @hearts :hearts
    @spades :spades
    @clubs :clubs
    @diamonds :diamonds

    # we forbid implicit creation by setting to nil
    defstruct value: nil, color: nil


    def colors, do: [@hearts, @spades, @clubs, @diamonds]

    def values,
      do: [
        @two,
        @three,
        @four,
        @five,
        @six,
        @seven,
        @eight,
        @nine,
        @ten,
        @jack,
        @queen,
        @king,
        @ace
      ]
  end

  defmacro deck() do
    Enum.zip(
      Card.values() |> List.duplicate(4) |> List.flatten(),
      Card.colors()
      |> Enum.map(fn
        c -> List.duplicate(c, length(Card.values()))
      end)
      |> List.flatten()
    )
    |> Enum.map(fn {v, c} -> %Card{value: v, color: c} end)
    #    |> IO.inspect()
    |> Macro.escape()
  end
end