defmodule Blackjack.Deck do
  @type card_value :: atom() | nil

  @type card_color :: atom() | nil

  @type card :: {card_value, card_color}

  defmodule Card do
    # TODO: attributes unneeded since only in this module...
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

    defimpl Inspect do
      import Inspect.Algebra

      def inspect(card, _opts) do
        concat(["#Blackjack.Deck.Card<", string("#{card}"), ">"])
      end

      # TODO we can make prettier render when pretty inspect option is on ?
    end

    defimpl String.Chars do
      def to_string(card) do
        value =
          case card.value do
            :two -> "2"
            :three -> "3"
            :four -> "4"
            :five -> "5"
            :six -> "6"
            :seven -> "7"
            :eight -> "8"
            :nine -> "9"
            :ten -> "10"
            :jack -> "J"
            :queen -> "Q"
            :king -> "K"
            # or "1" ?? depending on hand value ??
            :ace -> "A"
          end

        color =
          case card.color do
            :hearts -> "♥"
            :spades -> "♠"
            :clubs -> "♣"
            :diamonds -> "♦"
          end

        value <> color
      end
    end
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
