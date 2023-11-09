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
    # TODO with supervisor or not ??
    Surefire.Accounting.LogServer.start_link([])

    # TODO : REVIEW instructions to play blackjack over IEx.
    IO.puts("Create your player data : > me = Surefire.IExPlayer.new(:mememe, 100)")
    IO.puts("Start a game of Blackjack : > bj = Blackjack.new() ")
    IO.puts("Place a bet : > Blackjack.bet(bj, me, 51)")
    IO.puts("Deal cards : > Blackjack.deal(bj)")
    IO.puts("Interactive Play : > Blackjack.play(bj)")
    IO.puts("Resolve : > Blackjack.resolve(bj)")

    # TODO : instructions to play blackjack over IEx **with ledger and accounts**.
  end
end

defmodule Mix.Tasks.Monte do
  @moduledoc ~s"""
  The monte mix task: `mix help monte`

  This is aimed to be started with IEx:
  `iex -S mix monte`

  It will give you commands to run to play Three-card Monte in IEx.
  """
  use Mix.Task

  require IEx
  require Monte

  @shortdoc "Starts a game of Three-card Monte in IEx"
  def run(_) do
    # TODO with supervisor or not ??
    Surefire.Accounting.LogServer.start_link([])

    IO.puts("Create your player data : > me = Surefire.Avatar.new(:mememe)")
    IO.puts("Start a game of Monte : > m = Monte.new(:monte) ")
    IO.puts("add a player : > m = m |> Monte.add_player(me)")
    IO.puts("shuffle: > m = m |> Monte.shuffle()")
    IO.puts("stake: > m = m |> Monte.bet()")
    IO.puts("reveal: > m |> Monte.reveal()")

    # TODO : check winnings

    # TODO : instructions to play monte over IEx **with ledger and accounts**.
  end
end
