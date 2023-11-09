defprotocol Surefire.Game do
  @moduledoc ~s"""
  Round protocol to allow a Game to manipulate any rounds in the same way.
  """

  @type t :: any()

  @spec id(t) :: atom()
  def id(round)

  @spec enter(t, Surefire.Avatar.t()) :: t
  def enter(round, avatar)

  # TODO : return wins/losses
  @spec play(t) :: any
  def play(round)

  # TODO : do we have both a differentiable and a updateable game , like for state ??
  #  ! updateable !  (differentiable doesnt have much interest for us at this stage (game will be written for surefire lib, not adding surefire afterwards)
  # TODO : => a next_player/* and next_turn/* interface...
  #       to be able to hook bet update logic from surefire...

end

# TODO : another protocol for game state
# maybe merge later ?


defmodule Surefire.Game.Event do
  # OR eventmap directly ?

  @type t :: map()  # TODO : one event or multiple ?? makes sense ??

  # TODO : types
  # Event has a key that can be used in a map, and used as an index...

  def detect(%state_module{} = prev_state, current_state) do
    ev_map = state_module.diff(prev_state, current_state)

    # TODO : emit event map as expected...

    ev_map
  end

end



defmodule Surefire.Game.DifferentiableState do
  @moduledoc ~s"""
  One possible interface to a game state to retrieve events "after the fact"
    + can be done at any time, and out of control path
    - might inadvertently lose some meaningful events "update steps"

  Q: Is there any benefit to this /vs/ specific events being triggered ?
  """



  @type game_state :: map()

  # TODO : types
  @callback diff(game_state, game_state) :: Surefire.Game.Event.t()
  # return events
  # Note: out of contro path -> should be a protocol ?
end

defmodule Surefire.Game.UpdateableState do
  @moduledoc ~s"""
  One possible interface to a game state to retrieve events "when in control"
    + make sure to not lose events between updates
    - need to be called in the control path, while game is happening...

  Note :  this can be embedded in a module sending messages / events to another part of the code...
  """
  @type game_state :: map()

  #TODO : types
  @callback update(game_state) :: {game_state, Surefire.Game.Event.t()}
  # return new state
  # Note: in control path -> can be a behaviour ?
end



