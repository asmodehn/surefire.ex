defprotocol Surefire.GameEventHandler do
  def process(handler, event)
end

defmodule Surefire.Bets do
  @doc ~s"""
  Structure of bets.
    A map of stakes with key being a state of game
   for the game to decide which stake is winning or not
  """
  # TODO : maybe change this to BetMap module: manage only the link bet <-> player
  #  A bet can be a complex, evolutive thing... tied to game states/events


  defmodule Stake do
    defstruct holder: nil,
              amount: 0  # TODO : not just an amount,
    # but an amount with various update(event) functions
    # => protocol for bet update ?? or invert control flow ??
    # TODO : This is WIP

    @type amount :: non_neg_integer() | atom()

    @type t :: %__MODULE__{
            holder: atom(),
            amount: amount()
          }

    def new(holder, amount \\ 0) do
      %__MODULE__{
      holder: holder,
      amount: amount
      }
    end

    # TODO : this module will disappear as player_id will become the key of the betmap.


    def bet_update(%__MODULE__{} = stake, update_fun) do
      %{stake | amount: update_fun.(stake.amount)}
    end


  end

  @type t :: %{any => [Stake.t()]}

  @spec new() :: t
  def new() do
    %{}
  end

  # TODO : specific type for avatar/player id
  # OLD
  @spec stake(t, any, atom, non_neg_integer) :: t
  def stake(bets_map, game_event, stakeholder, amount) do
    stake = Stake.new(stakeholder, amount)

    bets_map
    |> Map.update(
      game_event,  # TODO : replace with stakeholder as key. keep event internal to game code.
      [stake],
      fn sl -> [stake | sl] end
    )
  end

  # NEW
  @spec stake(t, any, atom, non_neg_integer) :: t
  def stake(bets_map, stakeholder, bet) do
    {_curr, updated} = bets_map
                       |> Map.get_and_update( stakeholder, fn
     nil -> {nil, [bet]}
     bet_list when is_list(bet_list) -> { bet_list, [bet | bet_list]}
     # else: error in bets_map current data
     end)
    updated
  end

  # TODO : add accounting calls here instead of in game ??
  #   => what of the interface with avatar ??

  def winnings(bets_map, game_event, win_fun) do
    winnings(bets_map, game_event, win_fun, fn %Stake{} = s -> %{s | amount: 0} end)
  end

  # TODO : one at a time, instead of all at once ??
  # based on game event, that can happen any time in play...
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

  def tmp_eventhandler_process_double_or_nothing(bets_map, game_event) do
    bets_map |> Enum.map(fn

      {^game_event, stake_list} ->
        {game_event, stake_list |> Enum.map(fn %Stake{} = s -> %{s | amount: s.amount * 2} end)}

      {e, stake_list} ->
        {e,
        stake_list
          |> Enum.map(fn %Stake{} = s -> %{s | amount: 0} end)
          |> Enum.reject(fn s -> s.amount == 0 end)}

    end)
    |> Enum.filter(fn {k, v} -> length(v) > 0 end)
    |> Enum.into(%{})
  end

  # TODO : smthg like that ... maybe one player at a time instead ?
  def pnl_process(bets_map, game_event) do

    bets_map
    |> Enum.map(fn
      {avatar_id, stake_list} ->
        {avatar_id,
          stake_list
          |> Enum.map(fn
            s -> Stake.bet_update(s, &Surefire.GameEventHandler.process/1 )
          end)
          # TODO : make null bets disappear from the list...
        }
    end)
    |> Enum.filter(fn {k, v} -> length(v) > 0 end)
    |> Enum.into(%{})
  end


end
