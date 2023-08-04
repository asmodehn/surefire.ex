defmodule Blackjack.Card.Sigil do
  defmacro __using__(_opts \\ []) do
    quote do
      import Blackjack.Card.Sigil, only: [sigil_C: 2]
      import Kernel, except: [sigil_C: 2]
    end
  end

  defp from_str(rankstr, suit) when rankstr == "", do: nil

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

    # ad-hoc struct (before module has been defined)
    %{__struct__: Blackjack.Card, value: rank, color: suit}
  end

  @doc """
  A sigil to easily define playing cards as string.
    Two use cases are implemented:

      iex> ~C[1 6 10 J K]s
      iex> ~C[A♥ 10♣ Q♠ 7♦]
  """
  defmacro sigil_C({:<<>>, _meta, []}, []), do: []

  defmacro sigil_C({:<<>>, _meta, [str]}, []) do
    separator = :binary.compile_pattern([" ", ","])

    str
    |> String.split(separator)
    |> Enum.map(fn
      s ->
        case String.last(s) do
          "♥" -> from_str(String.slice(s, 0..-2//1), :hearts)
          "♠" -> from_str(String.slice(s, 0..-2//1), :spades)
          "♣" -> from_str(String.slice(s, 0..-2//1), :clubs)
          "♦" -> from_str(String.slice(s, 0..-2//1), :diamonds)
          unknown -> nil
        end
    end)
    # reject everything that didn't match previously
    |> Enum.reject(&is_nil/1)
    |> Macro.escape()
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?h]) do
    separator = :binary.compile_pattern([" ", ","])

    Macro.escape(str |> String.split(separator) |> Enum.map(&from_str(&1, :hearts)))
    # reject everything that didn't match previously
    |> Enum.reject(&is_nil/1)
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?s]) do
    separator = :binary.compile_pattern([" ", ","])

    Macro.escape(str |> String.split(separator) |> Enum.map(&from_str(&1, :spades)))
    # reject everything that didn't match previously
    |> Enum.reject(&is_nil/1)
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?c]) do
    separator = :binary.compile_pattern([" ", ","])

    Macro.escape(str |> String.split(separator) |> Enum.map(&from_str(&1, :clubs)))
    # reject everything that didn't match previously
    |> Enum.reject(&is_nil/1)
  end

  defmacro sigil_C({:<<>>, _meta, [str]}, [?d]) do
    separator = :binary.compile_pattern([" ", ","])

    Macro.escape(str |> String.split(separator) |> Enum.map(&from_str(&1, :diamonds)))
    # reject everything that didn't match previously
    |> Enum.reject(&is_nil/1)
  end
end

defmodule Blackjack.Card do
  # we forbid implicit creation by setting to nil
  defstruct value: nil, color: nil

  @type t :: %__MODULE__{
          # TODO : rank and suit instead...
          value: non_neg_integer(),
          color: atom()
        }

  use Blackjack.Card.Sigil

  def hearts(), do: ~C[2 3 4 5 6 7 8 9 10 J Q K A]h
  def spades(), do: ~C[2 3 4 5 6 7 8 9 10 J Q K A]s
  def clubs(), do: ~C[2 3 4 5 6 7 8 9 10 J Q K A]c
  def diamonds(), do: ~C[2 3 4 5 6 7 8 9 10 J Q K A]d

  def deck() do
    hearts ++ spades ++ clubs ++ diamonds
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(card, _opts) do
      concat(["#Blackjack.Card<", string("#{card}"), ">"])
    end

    # TODO we can make prettier render when pretty inspect option is on ?
    # SAME as SIGIL ??
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
