defmodule Surefire.Bets do
  @doc ~s"""
  Structure of bets.
    A map of stakes with key being a state of game for the game to decide which stake is winning or not
  """

  defmodule Stake do
    defstruct holder: nil,
              amount: 0

    @type t :: %__MODULE__{
            holder: atom(),
            amount: non_neg_integer() | atom()
          }
  end

  @type t :: %{any => [Stake.t()]}

  @spec new() :: t
  def new() do
    %{}
  end

  # TODO : specific type for avatar/player id
  @spec stake(t, any, atom, non_neg_integer) :: t
  def stake(bets_map, game_event, stakeholder, amount) do
    stake = %Stake{holder: stakeholder, amount: amount}

    bets_map
    |> Map.update(
      game_event,
      [stake],
      fn sl -> [stake | sl] end
    )
  end

  # TODO : add accounting calls here instead of in game ??
  #   => what of the interface with avatar ??

  def winnings(bets_map, game_event, win_fun) do
    winnings(bets_map, game_event, win_fun, fn %Stake{} = s -> %{s | amount: 0} end)
  end

  def winnings(bets_map, game_event, win_fun, lose_fun) do
    bets_map
    |> Enum.map(fn
      {^game_event, sl} ->
        {game_event, sl |> Enum.map(win_fun)}

      {p, sl} ->
        {p,
         sl
         |> Enum.map(lose_fun)
         |> Enum.reject(fn s -> s.amount == 0 end)}
    end)
    |> Enum.filter(fn {k, v} -> length(v) > 0 end)
    |> Enum.into(%{})
  end
end
