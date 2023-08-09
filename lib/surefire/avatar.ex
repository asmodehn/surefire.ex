defmodule Surefire.Avatar.Behaviour do
  @moduledoc """
  This module contains callbacks that can be called by players of a game
  They provide already implemented interface for a player interaction,
  assuming the player context is already known by other ways (iex, display, state, etc.)
  """
  @type return :: any()
  @callback decide(String.t(), %{(String.t() | atom()) => return()}) :: return()
end

defmodule Surefire.Avatar.Random do
  @moduledoc """
  This avatar decides randomly
  """

  @behaviour Surefire.Avatar.Behaviour

  @impl true
  def decide(prompt, choice_map) do
    keys = Map.keys(choice_map)
    choice_idx = Enum.random(0..(length(keys) - 1))
    # pick the answer
    choice_map[Enum.at(keys, choice_idx)]
  end
end

defmodule Surefire.Avatar.IEx do
  @moduledoc """
  This Avatar prompt in IEx to ask for the user decision.
  """

  @behaviour Surefire.Avatar.Behaviour

  @impl true
  def decide(prompt, choice_map) do
    keys = Map.keys(choice_map)
    choice_idx = ExPrompt.choose(prompt, keys)

    choice =
      case choice_idx do
        # extract value when key matches
        i when i in 0..(length(keys) - 1) -> choice_map[Enum.at(keys, i)]
        # loop otherwise(prbm with input...)
        _ -> decide(prompt, choice_map)
      end
  end
end
