



defmodule Blackjack.Player.Auto do

#  use GenServer
  # TODO GenServer to isolate any potential random seed.
  # BUT : some data is managed by game itself...


  defstruct name: "Computer", credits: 42


  def new(name, credits) do
    %__MODULE__{name: name, credits: credits}
  end

  defimpl Surefire.Player do


    def id(player) do
      player.id
    end

    def name(player) do
      player.name
    end

    def credits(player) do
      player.credits
    end

    def get(%Blackjack.Player.Auto{credits: c} = player, gain) do
      %{player | credits: c + gain}
    end

    def bet(%Blackjack.Player.Auto{credits: c} = player, bet) do
      %{ player | credits: c - bet}
    end

    def decide(%Blackjack.Player.Auto{} = player, prompt, choices) do

    end
  end

end



defmodule Blackjack.Player.Interactive do

  # Note: this is to enforce in design that Blackjack depends on Surefire,
  # But Surefire already has most of mandatory data for a game...
  # some extra data can be added if needed by the game however.
  defstruct sf: %Surefire.IExPlayer{},
            extra_stuff: nil

  def new() do
    %__MODULE__{sf: Surefire.IExPlayer.new()}
  end


  defimpl Surefire.Player do

    def id(player) do
      Surefire.Player.id(player.sf)
    end


    def name(player) do
      Surefire.Player.name(player.sf)
    end

    def credits(player) do
      Surefire.Player.credits(player.sf)
    end

    def bet(%Blackjack.Player.Interactive{} = player, bet) do
      Surefire.Player.bet(player.sf, bet)
    end

    def get(%Blackjack.Player.Interactive{} = player, gain) do
      Surefire.Player.get(player.sf, gain)
    end

    def decide(%Blackjack.Player.Interactive{} = player, prompt, choices) do
      Surefire.Player.decide(player.sf, prompt, choices)
    end
  end

end




#
#defmodule Blackjack.Player.Surefire do
#  defstruct surefire: %Surefire.IExPlayer{}
#
#  @behaviour Blackjack.Player
#
#  def new(name, impl) do
#    %__MODULE__{
#      id: String.to_atom(name),
#      surefire: impl.new(name)
#    }
#  end
#
#  @impl Blackjack.Player
#  def win(%__MODULE__{} = player, gain) do
#
#    IO.puts("You win #{gain} !")
#
#  end
#
#  @impl Blackjack.Player
#  def lose(%__MODULE__{} = player, loss) do
#
#    IO.puts("You loose #{loss}.")
#
#  end
#
#
#  @impl Blackjack.Player
#  def decide(%__MODULE__{} = player ,possible_actions) do
#
#  end
#
#
#  defimpl String.Chars do
#    def to_string(%Blackjack.Player{surefire: sf}), do: sf.name
#  end
#
#  defimpl Surefire.Player do
#
#    def string(%__MODULE__{
#      surefire: sf
#    }, prompt, opts \\ [required: true]) do
#      Surefire.Player.string(sf)
#    end
#
#    def choose(%__MODULE__{
#      surefire: sf
#    }, prompt, choices) do
#      Surefire.Player.choose(sf, prompt, choices)
#    end
#
#    def confirm(%__MODULE__{
#      surefire: sf
#    }, prompt) do
#      Surefire.Player.confirm(sf, prompt)
#    end
#
#    def password(%__MODULE__{
#      surefire: sf
#    }, prompt) do
#      Surefire.Player.password(sf, prompt)
#    end
#
#  end
#end

