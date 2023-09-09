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

  # TODO : maybe another kind of "bet" when there is no transaction involved ?
  def fake_bet(avatar)
  def bet(avatar, round_account_id)
  def hit_or_stand(avatar, hand, dealer_hand)
  def gain(avatar, round_account_id, amount)
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


    # never called
    def fake_bet(_avatar), do: nil
    # never called
    def bet(_avatar, _round_account_id), do: nil

    def hit_or_stand(%Blackjack.Dealer{} = _dealer, hand, _dealer_hand \\ nil) do
      if hand.value >= 17 do
        :stand
      else
        :hit
      end
    end

    # TODO : something to do here ?? what happens to funds ??
    def gain(avatar, round_account_id, amount), do: nil
    # TODO: increase Round account in its ledger...
  end
end

defimpl Blackjack.Avatar, for: Surefire.Avatar do
  # Note: player can be implemented in surefire side.
  # BUT: Avatar depends on the game and is implemented game side...

  alias Surefire.Accounting.AccountID

  def id(%Surefire.Avatar{} = avatar) do
    avatar.id
  end


  # default to nil for game ledger and round account, in case we do not want any proper accounting (dry-run)
  def fake_bet(%Surefire.Avatar{actions: actions} = avatar)
      when is_map_key(actions, :bet) do
    {bet, avatar} = Surefire.Avatar.call_mutation(avatar, :bet)

    {bet, avatar}
  end

  def fake_bet(%Surefire.Avatar{} = avatar) do
    answer = Surefire.Avatar.ask(avatar, "How much do you want to bet ?")
    {amount, ""} = Integer.parse(answer)

    _tid = Surefire.Avatar.fake_bet_transfer(avatar, amount)
    # TODO : return fake TID (nil !) + amount as usable reference ?
    {amount, avatar}
  end

  def bet(%Surefire.Avatar{actions: actions} = avatar, %AccountID{} = round_account_id)
      when is_map_key(actions, :bet) do
    # attempt automation
    {bet, avatar} = Surefire.Avatar.call_mutation(avatar, :bet, round_account_id)
    {bet, avatar}
  end

  def bet(%Surefire.Avatar{} = avatar, %AccountID{} = round_account_id) do
    answer = Surefire.Avatar.ask(avatar, "How much do you want to bet ?")
    {amount, ""} = Integer.parse(answer)

    _tid = Surefire.Avatar.bet_transfer(avatar, amount, round_account_id)
    # TODO : return TID + amount as usable reference ?
    {amount, avatar}
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

  def gain(%Surefire.Avatar{actions: actions} = avatar, %AccountID{} = round_account_id, amount)
      when is_map_key(actions, :gain) do
    # attempt automation
    {bet, avatar} = Surefire.Avatar.call_mutation(avatar, :gain, round_account_id)
    {bet, avatar}
  end

  def gain(%Surefire.Avatar{} = avatar, %AccountID{} = round_account_id, amount) do
    Surefire.Avatar.tell(avatar, "You gained #{amount}")

    _tid = Surefire.Avatar.gain_transfer(avatar, amount, round_account_id)
    # TODO : return TID + amount as usable reference ?
    {amount, avatar}
  end
end
