defmodule Blackjack.Avatar.Behaviour do
  @callback hit_or_stand(Hand.t(), Hand.t()) :: :hit | :stand
end

defmodule Blackjack.Dealer do
  @behaviour Blackjack.Avatar.Behaviour

  @impl true
  def hit_or_stand(hand, _dealer_hand \\ nil) do
    if hand.value >= 17 do
      :stand
    else
      :hit
    end
  end
end

defmodule Blackjack.Avatar.IEx do
  @behaviour Blackjack.Avatar.Behaviour

  @impl true
  def hit_or_stand(hand, dealer_hand) do
    Surefire.Avatar.IEx.decide(
      """
      Position at #{hand.value}.
      Dealer at #{dealer_hand.value}.
      What to do ?
      """,
      %{
        "One more card !" => :hit,
        "I'm good" => :stand
      }
    )
  end
end

defmodule Blackjack.Avatar.Random do
  @behaviour Blackjack.Avatar.Behaviour

  @impl true
  def hit_or_stand(_hand, _dealer_hand) do
    Enum.random([
      :stand,
      :hit
    ])
  end
end
