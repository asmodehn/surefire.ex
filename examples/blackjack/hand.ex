defmodule Blackjack.Hand do
  alias Blackjack.Deck.Card

  defstruct cards: [], value: 0

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

  def new(%Card{} = c) do
    # Note : first card is always evaluated with high value for an ace
    %__MODULE__{cards: [c], value: card_value(c)}
  end

  def add_card(%Blackjack.Hand{} = hand, %Card{} = c) do
    cards = hand.cards ++ [c]
    hand_value = cards |> Enum.map(&card_value/1) |> Enum.sum()

    hand_value =
      if hand_value <= 21,
        do: hand_value,
        else: cards |> Enum.map(fn c -> card_value(c, low_ace: true) end) |> Enum.sum()

    %{hand | cards: cards, value: hand_value}
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
end

# defmodule Blackjack.Rules do
# # TODO : aim is to replace /rename -> Table
# # => can have many
# # => just a deterministic state machine... (with some randomness hidden inside)
#
#  use GenStateMachine, callback_mode: :state_functions
#
#  def dealing({:call, from}, :deal_card, {hand, card}) do
#
#    if Blackjack.Hand.value(hand) + Blackjack.Hand.card_value(card) > 21  do
#
#    {:keep_state_and_data, [{:reply, from, Blackjack.Hand.bust(hand)}]}
#    else
#
#    {:keep_state_and_data, [{:reply, from, Blackjack.Hand}]}
#    end
#
#  end
#
#  def on(:cast, :flip, data) do
#    {:next_state, :off, data}
#  end
#
#  def on({:call, from}, :get_count, data) do
#    {:keep_state_and_data, [{:reply, from, data}]}
#  end
# end
