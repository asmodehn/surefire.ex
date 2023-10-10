# defmodule Surefire.Avatar.Behaviour do
#  @moduledoc """
#  This module contains callbacks that can be called by players of a game
#  They provide already implemented interface for a player interaction,
#  assuming the player context is already known by other ways (iex, display, state, etc.)
#  """
# end

defmodule Surefire.DryAvatar do
  @moduledoc ~s"""
  Avatar without any credits or capabilities for transactions.
    It uses "fake credits" instead.
  """

  # TODO
end

defmodule Surefire.Avatar.Automated do
  defstruct decide: nil,
            ask: nil,
            tell: nil,
            bet_transfer: nil,
            gain_transfer: nil

  # TODO : macro to detect full automation

  def automatize(%__MODULE__{} = auto, fun_id, fun)
      when is_map_key(%__MODULE__{}, fun_id) do
    auto |> Map.put(fun_id, fun)
  end

  def decide(%__MODULE__{} = auto, prompt, choice_map)
      when auto.decide != nil do
    auto.decide.(prompt, choice_map)
  end

  def ask(%__MODULE__{} = auto, prompt)
      when auto.ask != nil do
    auto.ask.(prompt)
  end

  def tell(%__MODULE__{} = auto, prompt)
      when auto.tell != nil do
    auto.tell.(prompt)
  end

  def bet_transfer(%__MODULE__{} = auto, amount, account_id)
      when auto.bet_transfer != nil do
    auto.bet_transfer.(amount, account_id)
  end

  def gain_transfer(%__MODULE__{} = auto, amount, account_id)
      when auto.gain_transfer != nil do
    auto.gain_transfer.(amount, account_id)
  end
end

defmodule Surefire.Avatar do
  # TODO : make avatar embed DryAvatar ?

  @moduledoc """
  This Avatar prompt in IEx to ask for the user decision.
  """

  alias Surefire.Accounting.{LedgerServer, AccountID}
  alias Surefire.Avatar.Automated

  defstruct id: nil,
            account_id: nil,
            automated: nil

  def new(id) do
    %__MODULE__{
      id: id
    }

    # TODO : no transaction -> fake bets -> dry-run
  end

  def new(id, %AccountID{} = player_account, %AccountID{} = account_id, funds \\ 0) do
    # create an account for the avatar in player ledger

    Surefire.Accounting.open_debit(account_id,
      from: player_account,
      amount: funds
    )

    %__MODULE__{
      id: id,
      account_id: account_id
    }
  end

  def automatize(%__MODULE__{automated: automated} = avatar, action_name, action_body) do
    automated = if automated == nil, do: %Automated{}, else: automated
    %{avatar | automated: automated |> Automated.automatize(action_name, action_body)}
  end

  # TODO : pass the game state for decision
  def decide(%__MODULE__{automated: auto} = avatar, prompt, choice_map)
      when auto.decide != nil do
    Automated.decide(auto, prompt, choice_map)
  end

  def decide(%__MODULE__{} = avatar, prompt, choice_map) do
    keys = Map.keys(choice_map)
    choice_idx = ExPrompt.choose(prompt, keys)

    _choice =
      case choice_idx do
        # extract value when key matches
        i when i in 0..(length(keys) - 1) -> choice_map[Enum.at(keys, i)]
        # loop otherwise(prbm with input...)
        _ -> decide(avatar, prompt, choice_map)
      end
  end

  # TODO : pass the game state for decision
  def ask(%__MODULE__{automated: auto} = _avatar, prompt)
      when auto.ask != nil do
    Automated.ask(auto, prompt)
  end

  def ask(%__MODULE__{} = _avatar, prompt) do
    ExPrompt.string_required(prompt)
  end

  # TODO : pass the game state for decision
  def tell(%__MODULE__{automated: auto} = _avatar, message)
      when auto.tell != nil do
    Automated.tell(auto, message)
  end

  def tell(%__MODULE__{} = _avatar, message) do
    IO.puts(message)
  end

  def fake_bet_transfer(
        %__MODULE__{} = _avatar,
        _amount
      ) do
    nil
  end

  def bet_transfer(
        %__MODULE__{account_id: account_id} = avatar,
        amount,
        %AccountID{} = round_account_id
      ) do
    t =
      Surefire.Accounting.transaction(
        # TODO : improve description...
        "#{avatar.id} transfer bet of #{amount} to #{round_account_id.account_id}"
      )
      |> Surefire.Accounting.debit_from(
        account_id,
        amount
      )
      |> Surefire.Accounting.debit_to(
        round_account_id,
        amount
      )

    LedgerServer.transfer(account_id.ledger_pid, t)
  end

  def gain_transfer(
        %__MODULE__{account_id: account_id} = avatar,
        amount,
        %AccountID{} = round_account_id
      ) do
    t =
      Surefire.Accounting.transaction(
        "#{avatar.id} transfer gains of #{amount} from #{round_account_id.account_id}"
      )
      |> Surefire.Accounting.debit_from(round_account_id, amount)
      |> Surefire.Accounting.debit_to(account_id, amount)

    LedgerServer.transfer(account_id.ledger_pid, t)
  end

  #  def request_funding(%__MODULE__{player_id: player_id} = avatar, amount) do
  #    # TODO : this semantics is handled by LedgerServer.transfer_credit/* (doesnt wait for authorization tho)
  #    Surefire.Player.request_funding(player_id, avatar.id, amount)
  #  end
end
