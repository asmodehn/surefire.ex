defmodule Blackjack.Card do
  # TODO: attributes unneeded since only in this module...
  #  @two :two
  #  @three :three
  #  @four :four
  #  @five :five
  #  @six :six
  #  @seven :seven
  #  @eight :eight
  #  @nine :nine
  #  @ten :ten
  #  @jack :jack
  #  @queen :queen
  #  @king :king
  #  # also one !
  #  @ace :ace

  # TODO: to prevent using the atoms around without checks, maybe we should make these functions, somehow ??

  #  @hearts :hearts
  #  @spades :spades
  #  @clubs :clubs
  #  @diamonds :diamonds

  # we forbid implicit creation by setting to nil
  defstruct value: nil, color: nil

  @type t :: %__MODULE__{
          value: non_neg_integer(),
          color: atom()
        }

  #
  #  def colors, do: [@hearts, @spades, @clubs, @diamonds]
  #
  #  def values,
  #    do: [
  #      @two,
  #      @three,
  #      @four,
  #      @five,
  #      @six,
  #      @seven,
  #      @eight,
  #      @nine,
  #      @ten,
  #      @jack,
  #      @queen,
  #      @king,
  #      @ace
  #    ]

  defmacro __using__(_opts \\ []) do
    quote do
      import Blackjack.Card, only: [sigil_C: 2]
      import Kernel, except: [sigil_C: 2]
    end
  end

  # TODO : lowercase  ANd upper case sigil, to alow/prevent interpolation
  # cf. http://elixir-br.github.io/getting-started/sigils.html#interpolation-and-escaping-in-sigils

  defp from_str(rankstr, suit) do
    rank =
      case rankstr do
        "1" -> :ace
        "2" -> :two
        "3" -> :three
        "4" -> :four
        "5" -> :five
        "6" -> :six
        "7" -> :seven
        "8" -> :eight
        "9" -> :nine
        "10" -> :ten
        "J" -> :jack
        "Q" -> :queen
        "K" -> :king
        "A" -> :ace
      end

    %__MODULE__{value: rank, color: suit}
  end

  @doc """
  A sigil to easily define playing cards as string.
    Two use cases are implemented:

      iex> ~C[1 6 10 J K]s
      iex> ~C[A♥ 10♣ Q♠ 7♦]
  """
  defmacro sigil_C({:<<>>, _meta, [str]}, []) do
    str
    |> String.split()
    |> Enum.map(fn
      s ->
        case String.last(s) do
          "♥" -> from_str(String.slice(s, 0..-2//1), :hearts)
          "♠" -> from_str(String.slice(s, 0..-2//1), :spades)
          "♣" -> from_str(String.slice(s, 0..-2//1), :clubs)
          "♦" -> from_str(String.slice(s, 0..-2//1), :diamonds)
        end
    end)
    |> Macro.escape()
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?h]) do
    Macro.escape(str |> String.split() |> Enum.map(&from_str(&1, :hearts)))
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?s]) do
    Macro.escape(str |> String.split() |> Enum.map(&from_str(&1, :spades)))
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?c]) do
    Macro.escape(str |> String.split() |> Enum.map(&from_str(&1, :clubs)))
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?d]) do
    Macro.escape(str |> String.split() |> Enum.map(&from_str(&1, :diamonds)))
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(card, _opts) do
      concat(["#Blackjack.Card<", string("#{card}"), ">"])
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
