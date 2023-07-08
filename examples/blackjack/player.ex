defmodule Blackjack.Player do
  defmodule PlayCommand do
    defstruct id: nil, command: :stand
  end

  defmodule GainEvent do
    defstruct id: nil, gain: 0
  end

  # Note: this is to enforce in design that Blackjack depends on Surefire,
  # But Surefire already has most of mandatory data for a game...
  # some extra data can be added if needed by the game however.
  defstruct sf: nil,
            extra_stuff: nil

  def new_interactive() do
    %__MODULE__{sf: Surefire.IExPlayer.new()}
  end

  def new_test(name, credits) do
    %__MODULE__{sf: Surefire.TestPlayer.new(name, credits)}
  end

  def event(%__MODULE__{} = player, gain) do
    %GainEvent{id: Surefire.Player.id(player.sf), gain: gain}
  end

  def hit_stand(%__MODULE__{} = player, hit_or_stand)
      when hit_or_stand in [:hit, :stand] do
    %PlayCommand{id: Surefire.Player.id(player.sf), command: hit_or_stand}
  end

  def hit_or_stand(%__MODULE__{} = player, value) do
    Surefire.Player.decide(
      player.sf,
      "Position at #{value}. What to do ?",
      %{
        "Hit" => hit_stand(player, :hit),
        "Stand" => hit_stand(player, :stand)
        # TODO : more options... Ref : https://en.wikipedia.org/wiki/Blackjack#Player_decisions
      }
    )
  end

  # TODO : automated (AI) player for multiplyer games...

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

    def bet(%Blackjack.Player{} = player, bet) do
      %Blackjack.Player{player | sf: Surefire.Player.bet(player.sf, bet)}
    end

    def get(%Blackjack.Player{} = player, gain) do
      %Blackjack.Player{player | sf: Surefire.Player.get(player.sf, gain)}
    end

    def decide(%Blackjack.Player{} = player, prompt, choices) do
      # TODO : same structure as other functions...
      Surefire.Player.decide(player.sf, prompt, choices)
    end
  end
end

#
# defmodule Blackjack.Player.Surefire do
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
# end
