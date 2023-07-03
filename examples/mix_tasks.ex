defmodule Mix.Tasks.Blackjack do
  @moduledoc ~s"""
  The blackjack mix task: `mix help blackjack`

  This is aimed to be started with IEx:
  `iex -S mix blackjack`

  It will give you commands to run to play blackjack in IEx.
  """
  use Mix.Task

  require IEx
  require Blackjack

  @shortdoc "Starts a game of blackjack in IEx"
  def run(_) do

    # TODO : instructions to play blackjack over IEx.
    IO.puts("Create your player data : > me = Blackjack.Player.Interactive.new()")
    IO.puts("Start a game of Blackjack : > bj = Blackjack.new([me]) ")
    IO.puts("Place a bet : > Blackjack.bet(bj, Surefire.Player.id(me), 51)")
    IO.puts("Deal cards : > Blackjack.deal(bj)")

  end
end