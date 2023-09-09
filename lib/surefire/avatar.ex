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

defmodule Surefire.Avatar do
  # TODO : make avatar embed DryAvatar

  @moduledoc """
  This Avatar prompt in IEx to ask for the user decision.
  """

  alias Surefire.Accounting.{LedgerServer, AccountID}

  defstruct id: nil,
            account_id: nil,
            actions: %{}

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

    # TODO : create account here instead of expecting to be called before this !
  end

  # TODO: different type of actions: read only | mutating avatar
  # TODO : or different API (pick one in server, statemachine, etc. ?)
  def with_action(%__MODULE__{} = avatar, action_name, action_body) do
    %{avatar | actions: avatar.actions |> Map.put(action_name, action_body)}
  end

  # TMP solution, we can probably do better
  def call_action(%__MODULE__{actions: actions}, action_name) do
    actions[action_name].()
  end

  def call_action(%__MODULE__{actions: actions}, action_name, param1) do
    actions[action_name].(param1)
  end

  def call_action(%__MODULE__{actions: actions}, action_name, param1, param2) do
    actions[action_name].(param1, param2)
  end

  def call_action(%__MODULE__{actions: actions}, action_name, param1, param2, param3) do
    actions[action_name].(param1, param2, param3)
  end

  def call_mutation(%__MODULE__{actions: actions} = avatar, action_name) do
    actions[action_name].(avatar)
  end

  def call_mutation(%__MODULE__{actions: actions} = avatar, action_name, param1) do
    actions[action_name].(avatar, param1)
  end

  def call_mutation(%__MODULE__{actions: actions} = avatar, action_name, param1, param2) do
    actions[action_name].(avatar, param1, param2)
  end

  def call_mutation(%__MODULE__{actions: actions} = avatar, action_name, param1, param2, param3) do
    actions[action_name].(avatar, param1, param2, param3)
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

  def ask(%__MODULE__{} = _avatar, prompt) do
    ExPrompt.string_required(prompt)
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
