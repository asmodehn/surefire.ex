# defmodule Blackjack.Avatar.Behaviour do
#  @callback id() :: atom
#  @callback hit_or_stand(Hand.t(), Hand.t()) :: :hit | :stand
# end

defprotocol Blackjack.Avatar do
  @moduledoc ~s"""
  Avatar protocol to allow any player to interact with blackjack rules.
  """

  def id(avatar)

  def hit_or_stand(avatar, hand, dealer_hand)
end

defmodule Blackjack.Dealer do
  @moduledoc ~s"""
  Hardcoded Avatar module for blackjack's dealer
  """

  defstruct id: :dealer

  defimpl Blackjack.Avatar do
    def id(%Blackjack.Dealer{} = dealer) do
      dealer.id
    end

    def hit_or_stand(%Blackjack.Dealer{} = dealer, hand, _dealer_hand \\ nil) do
      if hand.value >= 17 do
        :stand
      else
        :hit
      end
    end
  end
end

defmodule Blackjack.Avatar.IEx do
  defstruct id: nil

  def new(id) do
    %__MODULE__{id: id}
  end

  defimpl Blackjack.Avatar do
    def id(%Blackjack.Avatar.IEx{} = avatar) do
      avatar.id
    end

    def hit_or_stand(%Blackjack.Avatar.IEx{} = avatar, hand, dealer_hand) do
      Surefire.Avatar.IEx.decide(
        """
        #{id(avatar)} position at #{hand.value}.
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
end

defmodule Blackjack.Avatar.Random do
  defstruct id: nil

  def new(id) do
    %__MODULE__{id: id}
  end

  defimpl Blackjack.Avatar do
    def id(%Blackjack.Avatar.Random{} = avatar) do
      avatar.id
    end

    def hit_or_stand(%Blackjack.Avatar.Random{} = avatar, _hand, _dealer_hand) do
      Enum.random([
        :stand,
        :hit
      ])
    end
  end
end

defmodule Blackjack.Avatar.Custom do
  defstruct id: nil, hit_or_stand: nil

  def new(id, hit_or_stand) do
    %__MODULE__{id: id, hit_or_stand: hit_or_stand}
  end

  defimpl Blackjack.Avatar do
    def id(%Blackjack.Avatar.Custom{} = avatar) do
      avatar.id
    end

    def hit_or_stand(%Blackjack.Avatar.Custom{} = avatar, hand, dealer_hand) do
      avatar.hit_or_stand.(hand, dealer_hand)
    end
  end
end
