# TODO : a bookie module, managing bets
# A bet is a collectible (with into/1) to implicitely accumulate the amount.
# While registering (as events) each individual interaction with the sportsbook...
# just like an accountant...

# Note : event infra should be interchangeable...
# => we need a functional structure for such behaviour first. then leverage a protocol/behaviour.

defmodule Surefire.Bookie do
  defmodule Position do
    # functions returning atom
    defstruct outcome: nil,
              # atom pointing to bet
              amount: 0

    # TODO : outcome and reward ?
    # instead of storing bet, it would make sure the bank is provisioned to pay reward...

    def new() do
    end

    defimpl Collectable do
      # multiple bets into the "same position" cumulate...
      def into(position) do
      end
    end
  end

  # player id pointing to positions... ??
  defstruct smthg: nil

  # TODO : also propose opportunities (bookie sets the odds, based on the game)

  def open_position(books, player) do
  end
end
