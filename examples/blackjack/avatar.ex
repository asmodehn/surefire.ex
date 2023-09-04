# defmodule Blackjack.Avatar.Behaviour do
#  @callback id() :: atom
#  @callback hit_or_stand(Hand.t(), Hand.t()) :: :hit | :stand
# end
# TODO : rename to `Blackjack.Player` instead ?
# BUT still matches the Surefire.Avatar module...
# TODO : behaviour instead (simpler) ??
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

