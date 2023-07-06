defmodule Blackjack.Hand do
  alias Blackjack.Deck.Card

  def card_value(%Card{value: v}, opts \\ [low_ace: false]) do
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

  def value(cards, opts \\ [low_ace: false]) when is_list(cards) do
    low_ace = Keyword.get(opts, :low_ace, false)

    val =
      cards
      |> Enum.map(&card_value/1)
      |> Enum.sum()

    cond do
      val > 21 ->
        if low_ace do
          :bust
        else
          value(cards, low_ace: true)
        end

      val == 21 ->
        :blackjack

      true ->
        val
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
