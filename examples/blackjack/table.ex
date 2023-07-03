
defmodule Blackjack.Table do

  defmodule Position do

    alias Blackjack.Deck.Card

    @type t :: list

    def card_value(%Card{value: v}, opts \\ [low_ace: false]) do
      low_ace = Keyword.get(opts, :low_ace, false)

      case v do
        :two -> 2
        :three -> 3
        :four -> 4
        :five -> 5
        :six -> 6
        :seven -> 7
        :eight -> 8
        :nine -> 9
        :ten -> 10
        :jack -> 10
        :queen -> 10
        :king -> 10
        :ace -> if low_ace, do: 1, else: 11
      end
    end


  def check_value(cards, opts \\ [low_ace: false]) do
    low_ace = Keyword.get(opts, :low_ace, false)

    val = cards
    |> Enum.map(fn c -> card_value(c) end)
    |> Enum.sum()

                cond do

     val > 21 -> if low_ace do
                                      :bust
                                         else
                                         check_value(cards, low_ace: true)
                  end
      val == 21 -> :blackjack
      true -> val
                             end



  end




  end


  import Blackjack.Deck, only: [deck: 0]

  @derive {Inspect, only: [:dealer, :positions]}
  defstruct shoe: [], dealer: [], positions: %{}

  def new(_decks \\ 3) do
    %__MODULE__{
      shoe: Enum.shuffle(deck()) ++ Enum.shuffle(deck()) ++ Enum.shuffle(deck())
    }
  end

  def deal_card(%__MODULE__{} = table, players)
      when  is_list(players) do

      players
      |> Enum.uniq()
      |> Enum.reduce(table, fn
        p, t -> deal_card(t, p)
      end)

    end


    def deal_card(%__MODULE__{shoe: shoe} = table, :dealer)
      when is_list(shoe) do

    [card | shoe ]=shoe

    %{table |
      shoe: shoe,
      dealer: table.dealer ++ [card]
    }
  end

    def deal_card(%__MODULE__{shoe: shoe} = table, player)
      when is_list(shoe) and is_atom(player) do

    [card | shoe ]=shoe

    %{table |
      shoe: shoe,
      positions: Map.merge(
                 table.positions,
                  Map.new([{player, [card]}]),
                  fn _k, l1, l2 -> l1 ++ l2 end)
    }
  end


    def check_value(%__MODULE__{} = table, :dealer) do
      dealer_position = table.dealer |> Position.check_value()

      case dealer_position do
        :bust -> :bust
        :blackjack -> :blackjack
        v -> v
      end

  end

    def check_value(%__MODULE__{} = table, player) do
      player_position = table.positions[player] |> Position.check_value()

      case player_position do
        :bust -> :bust
        :blackjack -> :blackjack
        v -> v
      end

  end

  def player_bust(%__MODULE__{positions: pos} = table, player) do

    %{table | positions: pos |> Map.drop(player)}

  end



end