defprotocol Surefire.Round do
  @moduledoc ~s"""
  Round protocol to allow a Game to manipulate any rounds in the same way.
  """

  def id(round)

  # TODO : similar api to a GenServer (for straight-forward embedding)
end
