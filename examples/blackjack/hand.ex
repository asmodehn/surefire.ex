defmodule Blackjack.Hand do
  alias Blackjack.Card

  defstruct cards: [], value: 0

  @type hand_value :: non_neg_integer | :blackjack | :bust
  @type t :: %__MODULE__{
          cards: [Card.t()],
          value: hand_value
        }

  defp card_value(%Card{value: v}, opts \\ [low_ace: false]) do
    low_ace = Keyword.get(opts, :low_ace, false)

    case v do
      :two -> 2
      :three -> 3
      :four -> 4
      :five -> 5
      :six -> 6
      :seven -> 7
      :eight -> 8
      :nine -> 9
      :ten -> 10
      :jack -> 10
      :queen -> 10
      :king -> 10
      :ace -> if low_ace, do: 1, else: 11
    end
  end

  @spec value([Card.t()]) :: hand_value
  def value(cards) when is_list(cards) do
    hand_value = cards |> Enum.map(&card_value/1) |> Enum.sum()

    if hand_value <= 21,
      do: hand_value,
      else: cards |> Enum.map(fn c -> card_value(c, low_ace: true) end) |> Enum.sum()

    cond do
      hand_value > 21 -> :bust
      hand_value == 21 -> :blackjack
      true -> hand_value
    end
  end

  def new() do
    %__MODULE__{cards: [], value: 0}
  end

  def add_card(%__MODULE__{} = hand, %Card{} = c) do
    cards = hand.cards ++ [c]
    %{hand | cards: cards, value: value(cards)}
  end

  def size(%__MODULE__{} = hand) do
    length(hand.cards)
  end

  @spec compare(t(), t()) :: :gt | :eq | :lt
  def compare(%__MODULE__{} = hl, %__MODULE__{} = hr)
      when is_integer(hl.value) and is_integer(hr.value) do
    cond do
      hl.value > hr.value -> :gt
      hl.value == hr.value -> :eq
      hl.value < hr.value -> :lt
    end
  end

  def compare(%__MODULE__{} = hl, %__MODULE__{} = hr)
      when is_atom(hl.value) or is_atom(hr.value) do
    cond do
      # equality should be treated first.
      hl.value == hr.value -> :eq
      hl.value == :blackjack -> :gt
      hl.value == :bust -> :lt
      hr.value == :blackjack -> :lt
      hr.value == :bust -> :gt
      true -> raise %RuntimeError{message: "Unhandled compare/2 case: #{hl} ~ #{hr}"}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Blackjack.Hand{} = hand, _opts) do
      concat(["#Blackjack.Hand<", string("#{hand}"), ">"])
    end

    # TODO we can make prettier render when pretty inspect option is on ?
  end

  defimpl String.Chars do
    def to_string(%Blackjack.Hand{} = hand) do
      cards = for c <- hand.cards, do: "#{c}"

      Enum.join(cards, ",") <> ": #{hand.value}"
    end
  end

  defimpl Collectable do
    def into(%Blackjack.Hand{} = hand) do
      collector_fun = fn
        hand_acc, {:cont, card} ->
          Blackjack.Hand.add_card(hand_acc, card)

        hand_acc, :done ->
          hand_acc

        _hand_acc, :halt ->
          :ok
      end

      initial_acc = hand

      {initial_acc, collector_fun}
    end
  end
end
