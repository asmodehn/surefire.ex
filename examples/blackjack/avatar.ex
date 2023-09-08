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

  # TODO : maybe another kind of "bet" when there is no transaction involved ?
  def fake_bet(avatar)
  def bet(avatar, game_ledger_pid, round_account_id)
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

  def bet(%Surefire.Avatar{actions: actions} = avatar, game_ledger_pid, round_account_id)
      when is_map_key(actions, :bet) and is_pid(game_ledger_pid) and is_atom(round_account_id) do
    # attempt automation
    {bet, avatar} = Surefire.Avatar.call_mutation(avatar, :bet, game_ledger_pid, round_account_id)
  end

  def bet(%Surefire.Avatar{} = avatar, game_ledger_pid, round_account_id)
      when is_pid(game_ledger_pid) and is_atom(round_account_id) do
    answer = Surefire.Avatar.ask(avatar, "How much do you want to bet ?")
    {amount, ""} = Integer.parse(answer)

    _tid = Surefire.Avatar.bet_transfer(avatar, amount, game_ledger_pid, round_account_id)
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
end
