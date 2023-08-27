# defmodule Blackjack.Avatar.Behaviour do
#  @callback id() :: atom
#  @callback hit_or_stand(Hand.t(), Hand.t()) :: :hit | :stand
# end

defprotocol Blackjack.Avatar do
  @moduledoc ~s"""
  Avatar protocol to allow any player to interact with blackjack rules.
  """

  def id(avatar)
  def player_id(avatar)

  def bet(avatar)
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

    def player_id(dealer), do: nil

    def hit_or_stand(%Blackjack.Dealer{} = dealer, hand, _dealer_hand \\ nil) do
      if hand.value >= 17 do
        :stand
      else
        :hit
      end
    end
  end
end

# defmodule Blackjack.Avatar.IEx do
#  defstruct id: nil, player_id: nil
#
#  # TODO : new API : from_player for_round => generate with custom algo in surefire...
#  def new(id, player_id) do
#    %__MODULE__{id: id, player_id: player_id}
#  end
#
#  defimpl Blackjack.Avatar do
#    def id(%Blackjack.Avatar.IEx{} = avatar) do
#      avatar.id
#    end
#
#    def player_id(avatar) do
#      avatar.player_id
#    end
#
#    def hit_or_stand(%Blackjack.Avatar.IEx{} = avatar, hand, dealer_hand) do
#      Surefire.Avatar.IEx.decide(
#        """
#        #{id(avatar)} position at #{hand.value}.
#        Dealer at #{dealer_hand.value}.
#        What to do ?
#        """,
#        %{
#          "One more card !" => :hit,
#          "I'm good" => :stand
#        }
#      )
#    end
#  end
# end

defimpl Blackjack.Avatar, for: Surefire.Avatar do
  # Note: player can be implemented in surefire side.
  # BUT: Avatar depends on the game and is implemented game side...

  def id(%Surefire.Avatar{} = avatar) do
    avatar.id
  end

  def player_id(%Surefire.Avatar{} = avatar) do
    avatar.player_id
  end

  def bet(%Surefire.Avatar{actions: actions} = avatar)
      when is_map_key(actions, :bet) do
    # attempt automation
    {bet, avatar} = Surefire.Avatar.call_mutation(avatar, :bet)
  end

  def bet(%Surefire.Avatar{} = avatar) do
    answer = Surefire.Avatar.ask(avatar, "How much do you want to bet ?")
    amount = Integer.parse!(answer)

    transaction = Surefire.Avatar.bet_transaction(avatar, amount)
    # TODO Store transaction in history to reflect transfer in account.
    updated_avatar = avatar

    {amount, updated_avatar}
  end

  def hit_or_stand(%Surefire.Avatar{actions: actions} = avatar, hand, dealer_hand)
      when is_map_key(actions, :hit_or_stand) do
    # attempt automation
    Surefire.Avatar.call_action(avatar, :hit_or_stand, hand, dealer_hand)
  end

  def hit_or_stand(%Surefire.Avatar{} = avatar, hand, dealer_hand) do
    # otherwise interactive
    Surefire.Avatar.decide(
      avatar,
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

# defmodule Blackjack.Avatar.Random do
#  defstruct id: nil, player_id: nil
#
#  def new(id, player_id) do
#    %__MODULE__{id: id, player_id: player_id}
#  end
#
#  defimpl Blackjack.Avatar do
#    def id(%Blackjack.Avatar.Random{} = avatar) do
#      avatar.id
#    end
#
#    def player_id(avatar) do
#      avatar.player_id
#    end
#
#    def hit_or_stand(%Blackjack.Avatar.Random{} = avatar, _hand, _dealer_hand) do
#      Enum.random([
#        :stand,
#        :hit
#      ])
#    end
#  end
# end
#
# defmodule Blackjack.Avatar.Custom do
#  defstruct id: nil, player_id: nil, hit_or_stand: nil
#
#  def new(id, player_id, hit_or_stand) do
#    %__MODULE__{id: id, player_id: player_id, hit_or_stand: hit_or_stand}
#  end
#
#  defimpl Blackjack.Avatar do
#    def id(%Blackjack.Avatar.Custom{} = avatar) do
#      avatar.id
#    end
#
#    def player_id(avatar) do
#      avatar.player_id
#    end
#
#    def hit_or_stand(%Blackjack.Avatar.Custom{} = avatar, hand, dealer_hand) do
#      avatar.hit_or_stand.(hand, dealer_hand)
#    end
#  end
# end
