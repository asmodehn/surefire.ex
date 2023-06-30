defmodule Blackjack.Deck do
  @type card_value :: atom() | nil

  @type card_color :: atom() | nil

  @type card :: {card_value, card_color}

  defmodule Card do
    @two :two
    @three :three
    @four :four
    @five :five
    @six :six
    @seven :seven
    @eight :eight
    @nine :nine
    @ten :ten
    @jack :jack
    @queen :queen
    @king :king
    # also one !
    @ace :ace

    @hearts :hearts
    @spades :spades
    @clubs :clubs
    @diamonds :diamonds

    # we forbid implicit creation by setting to nil
    defstruct value: nil, color: nil


    def colors, do: [@hearts, @spades, @clubs, @diamonds]

    def values,
      do: [
        @two,
        @three,
        @four,
        @five,
        @six,
        @seven,
        @eight,
        @nine,
        @ten,
        @jack,
        @queen,
        @king,
        @ace
      ]
  end

  defmacro deck() do
    Enum.zip(
      Card.values() |> List.duplicate(4) |> List.flatten(),
      Card.colors()
      |> Enum.map(fn
        c -> List.duplicate(c, length(Card.values()))
      end)
      |> List.flatten()
    )
    |> Enum.map(fn {v, c} -> %Card{value: v, color: c} end)
    #    |> IO.inspect()
    |> Macro.escape()
  end
end

defmodule Blackjack.Bets do
  defstruct bets: []

  def player_bet(%__MODULE__{} = b, player, bet) do
    %{b | bets: Keyword.update(b.bets, player, bet, fn v -> v + bet end)}
  end

  def players(%__MODULE__{bets: b}) do
    Keyword.keys(b)
  end
end

defmodule Blackjack.Table do
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


end


defmodule Blackjack do
  alias Blackjack.{Bets, Table, Deck}

  @derive {Inspect, only: [:bets, :table]}
  defstruct players: [],
            bets: %Bets{},
            table: %Table{}


    def card_value(%Deck.Card{value: v}, opts \\ [low_ace: false]) do
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

  def new(players) do
    %__MODULE__{
      players: players |> Enum.map(&String.to_atom/1),
      table: Table.new()
    }
  end
  # TODO : new and bet are the same ? (blind bets -> start game ??)

  def bet(%__MODULE__{bets: bets} = game, player, amount)
      when is_atom(player) and is_number(amount) do
    players = if player not in game.players do
      game.players ++ [player]
    else
      game.players
    end

    %{game |
      players: players,
      bets: bets |> Bets.player_bet(player, amount)
    }
  end

  @doc ~s"""
    Only take in the game players who have already bet something...
  """
  def deal(%__MODULE__{bets: bets} = game) do
    players = Bets.players(bets)
    %{game | players: players,
      table: game.table
            |> Table.deal_card( Bets.players(bets) ++ [:dealer])
            |> Table.deal_card( Bets.players(bets) ++ [:dealer])
    }
  end


  def player_action(%__MODULE__{} = game, player, action)
    when action in [:hit, :stand] do

    if action == :hit do
      %{game | table: game.table
              |> Table.deal_card(player)
      }
    else
      game
    end

  end





end
