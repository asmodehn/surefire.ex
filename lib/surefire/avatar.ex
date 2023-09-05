# defmodule Surefire.Avatar.Behaviour do
#  @moduledoc """
#  This module contains callbacks that can be called by players of a game
#  They provide already implemented interface for a player interaction,
#  assuming the player context is already known by other ways (iex, display, state, etc.)
#  """
# end

# defmodule Surefire.Avatar.Random do
#  @moduledoc """
#  This avatar decides randomly
#  """
#
#  @behaviour Surefire.Avatar.Behaviour
#
#  @impl true
#
# end

defmodule Surefire.Avatar do
  @moduledoc """
  This Avatar prompt in IEx to ask for the user decision.
  """

  defstruct id: nil,
            # TODO: player_id is TMP and should not be needed when we can use transaction for gains.
            player_id: nil,
            # TODO : BUT this is useful to find remote ledger server...
            player_pid: nil,
            account_id: nil,
            actions: %{}

  def new(id, player_id) do
    %__MODULE__{
      id: id,
      player_id: player_id
    }

    # TODO : no transaction -> fake bets -> dry-run
  end

  def new(id, player_id, player_pid, account_id) do
    %__MODULE__{
      id: id,
      player_id: player_id,
      player_pid: player_pid,
      account_id: account_id
    }
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

  def fake_bet_transfer(
        %__MODULE__{player_pid: player_pid, account_id: account_id} = avatar,
        amount
      ) do
    nil
  end

  def bet_transfer(
        %__MODULE__{player_pid: player_pid, account_id: account_id} = avatar,
        amount,
        game_ledger_pid,
        round_account_id
      ) do
    tid =
      Surefire.Accounting.LedgerServer.transfer_to_ledger(
        # from
        player_pid,
        account_id |> IO.inspect(),
        # to
        game_ledger_pid,
        round_account_id,
        amount
      )

    # TODO : how to change description ??

    tid
  end

  def request_funding(%__MODULE__{player_id: player_id} = avatar, amount) do
    Surefire.Player.request_funding(player_id, avatar.id, amount)
  end
end
