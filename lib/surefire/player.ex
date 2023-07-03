

defprotocol Surefire.Player do


  def id(player)
  def name(player)
  def credits(player)


  def get(player, gain)
  def bet(player, bet)

  def decide(player, prompt, choices)


end


defmodule Surefire.IExPlayer do

  defstruct name: nil, credits: 0


  def new() do
    name = ExPrompt.string_required("What is your name ? ")
    {credits,""} = ExPrompt.string("How much credits do you have? " )
              |> Integer.parse()

    new(name, credits)
  end

  # TODO : only one player per iex session -> HOW ??

    def new(name, credits) do
      %Surefire.IExPlayer{name: name, credits: credits}
    end

  #TODO : decorate iex session to show name of player ?
  # Note the game being played is hte usual behaviour of function calls in IEx.
  # Only the player interaction requires special handling (communication the "other way".)

  defimpl Surefire.Player do


    def id(player) do
      String.to_atom(player.name)
    end

    def name(player) do
      player.name
    end

    def credits(player) do
      player.credits
    end

    def bet(player, bet) do
      IO.puts("#{player}/You bet #{bet}")
      %{player | credits: player.credits - bet}
    end

    def get(player, gain) do
      IO.puts("#{player}/You get #{gain}")
      %{player | credits: player.credits + gain}
    end

    def decide(player, prompt, choices) do
      ExPrompt.choose(prompt, choices)
      # optionally modify player...
      player
    end
  end


  defimpl String.Chars do
    def to_string(player), do: player.name
  end

end

