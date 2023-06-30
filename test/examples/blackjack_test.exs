defmodule Blackjack.DeckTest do
    use ExUnit.Case, async: true

    alias Blackjack.Deck.Card
    import Blackjack.Deck, only: [deck: 0]

    test "deck/0 macro generates a complete deck properly ordered" do

      colorh = :hearts
      colors = :spades
      colorc = :clubs
      colord = :diamonds

      hearts =  [%Card{value: :two, color: colorh},
             %Card{value: :three, color: colorh},
             %Card{value: :four, color: colorh},
             %Card{value: :five, color: colorh},
             %Card{value: :six, color: colorh},
             %Card{value: :seven, color: colorh},
             %Card{value: :eight, color: colorh},
             %Card{value: :nine, color: colorh},
             %Card{value: :ten, color: colorh},
             %Card{value: :jack, color: colorh},
             %Card{value: :queen, color: colorh},
             %Card{value: :king, color: colorh},
             %Card{value: :ace, color: colorh}
             ]
      spades = [%Card{value: :two, color: colors},
             %Card{value: :three, color: colors},
             %Card{value: :four, color: colors},
             %Card{value: :five, color: colors},
             %Card{value: :six, color: colors},
             %Card{value: :seven, color: colors},
             %Card{value: :eight, color: colors},
             %Card{value: :nine, color: colors},
             %Card{value: :ten, color: colors},
             %Card{value: :jack, color: colors},
             %Card{value: :queen, color: colors},
             %Card{value: :king, color: colors},
             %Card{value: :ace, color: colors}
             ]
      clubs = [%Card{value: :two, color: colorc},
             %Card{value: :three, color: colorc},
             %Card{value: :four, color: colorc},
             %Card{value: :five, color: colorc},
             %Card{value: :six, color: colorc},
             %Card{value: :seven, color: colorc},
             %Card{value: :eight, color: colorc},
             %Card{value: :nine, color: colorc},
             %Card{value: :ten, color: colorc},
             %Card{value: :jack, color: colorc},
             %Card{value: :queen, color: colorc},
             %Card{value: :king, color: colorc},
             %Card{value: :ace, color: colorc}
             ]
      diamonds = [%Card{value: :two, color: colord},
             %Card{value: :three, color: colord},
             %Card{value: :four, color: colord},
             %Card{value: :five, color: colord},
             %Card{value: :six, color: colord},
             %Card{value: :seven, color: colord},
             %Card{value: :eight, color: colord},
             %Card{value: :nine, color: colord},
             %Card{value: :ten, color: colord},
             %Card{value: :jack, color: colord},
             %Card{value: :queen, color: colord},
             %Card{value: :king, color: colord},
             %Card{value: :ace, color: colord}
             ]

      assert deck() == hearts ++ spades ++ clubs ++ diamonds
    end


end

defmodule Blackjack.BetsTest do
  use ExUnit.Case, async: true

  alias Blackjack.Bets

  test "player_bet/3 adds a bet for this player" do

    assert %Bets{bets: [ alice: 1, bob: 2]}
|> Bets.player_bet(:alice, 3) == %Bets{bets: [ alice: 4, bob: 2]}


  end


end

defmodule Blackjack.TableTest do

  use ExUnit.Case, async: true
  alias Blackjack.Table

  import Blackjack.Deck, only: [deck: 0]

  test "new/0 creates a new Table with a shoe with 3 decks" do

    assert length(Table.new().shoe) == 3 * length(deck())


  end

  describe "deal_card/2" do
     test "can deal a card to the dealer" do
       table = Table.new()
       |> Table.deal_card(:dealer)

       assert length(table.dealer) == 1
       assert %Blackjack.Deck.Card{} = List.first(table.dealer)

     end

     test "can deal a card to a player" do
       table = Table.new()
       |> Table.deal_card(:bob)

       assert :bob in Map.keys(table.positions)
       assert length(table.positions[:bob]) == 1
       assert %Blackjack.Deck.Card{} = List.first(table.positions[:bob])

     end

     test "can deal a card to many players, including dealer" do
            table = Table.new()
       |> Table.deal_card([:alice, :bob, :dealer])


            assert :alice in Map.keys(table.positions)
       assert :bob in Map.keys(table.positions)

       assert length(table.dealer) == 1
       assert length(table.positions[:alice]) == 1
       assert length(table.positions[:bob]) == 1


       assert %Blackjack.Deck.Card{} = List.first(table.dealer)
       assert %Blackjack.Deck.Card{} = List.first(table.positions[:alice])
       assert %Blackjack.Deck.Card{} = List.first(table.positions[:bob])



     end

  end


end