defmodule Blackjack.Event do
  # TODO : Generic events, or relative to player (Blackjack or Surefire's ?)
  defmodule PlayerEnter do
    defstruct id: nil, bet: 0
  end

  defmodule PlayerOut do
    defstruct id: nil, prompt: "", choice: %{}
  end

  defmodule PlayerIn do
    defstruct id: nil, action: nil
  end

  defmodule PlayerExit do
    defstruct id: nil, gain: 0
  end

  def player_enter(player, bet) do
    %PlayerEnter{id: Surefire.Player.id(player), bet: bet}
  end

  def player_out(player, prompt, choice \\ %{}) do
    %PlayerOut{id: Surefire.Player.id(player), prompt: prompt, choice: choice}
  end

  def player_in(player, action) do
    %PlayerIn{id: Surefire.Player.id(player), action: action}
  end

  def player_exit(player, gain) do
    %PlayerExit{id: Surefire.Player.id(player), gain: gain}
  end
end
