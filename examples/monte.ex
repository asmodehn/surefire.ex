defmodule Monte do
  @moduledoc ~s"""
    ## References:
    - https://en.wikipedia.org/wiki/Three-card_Monte

    ## Examples

  Create your player data :
      iex> me = Surefire.Avatar.new(:mememe)

    Start a game of Monte :
      iex> m = Monte.new(:monte)

    add a player :
      iex> m = m |> Monte.add_player(me)

  shuffle:
      iex> m = m |> Monte.shuffle()

  stake:
      iex> m = m |> Monte.bet()

  reveal:
      iex> m |> Monte.reveal()

  """

  # TODO :  replace this with same cards as blackjack...
  @jclubs :jack_of_clubs
  @jspades :jack_of_spades
  @qhearts :queen_of_hearts

  # TODO: implement game state diff behaviour/protocol here...

  defstruct id: nil,
            cards: [],
            players: %{},
            bets: %{}

  def new(id, cards \\ [@jclubs, @jspades, @qhearts]) do
    %__MODULE__{
      id: id,
      cards: cards
    }
  end

  def add_player(%__MODULE__{players: players} = game, %Surefire.Avatar{} = avatar) do
    %{game | players: players |> Map.put(avatar.id, avatar)}
  end

  def shuffle(%__MODULE__{cards: cards} = game) do
    game = %{game | cards: Enum.shuffle(cards)}
  end

  def bet(%__MODULE__{players: avatars} = game) do
    for {av_id, avatar} <- avatars, reduce: game do
      game_acc -> bet(game_acc, avatar)
    end
  end

  def bet(%__MODULE__{bets: bets} = game, %Surefire.Avatar{} = avatar) do
    card_pos =
      avatar
      |> Surefire.Avatar.decide("Where is the queen of hearts ?", %{
        "position 0" => 0,
        "position 1" => 1,
        "position 2" => 2
      })

    {amount, ""} =
      avatar
      |> Surefire.Avatar.ask("How much are you ready to bet on it ?")
      |> Integer.parse()

    # TODO : bet transaction for Avatar

    %{
      game
      | bets:
          bets
          |> Surefire.Bets.stake(card_pos, avatar.id, amount)
    }
  end

  def reveal(%__MODULE__{players: avatars} = game) do
    for {av_id, avatar} <- avatars, reduce: game do
      game_acc -> reveal(game_acc, av_id)
    end
  end

  def reveal(%__MODULE__{players: avatars} = game, avatar_id) do
    q_index = game.cards |> Enum.find_index(fn c -> c == @qhearts end)

    %{
      game
      | bets:
          game.bets
          # TODO : fix this, SIMPLY ! avoid defining a specific bet module, as an exercise...

          |> Surefire.Bets.tmp_eventhandler_process_double_or_nothing(
#          avatar_id
               q_index
             )
#          |> Surefire.Bets.winnings(avatar_id, fn
#            s -> %{s | amount: s.amount * 2}
#          end)
    }

    # TODO : gain transaction for winning Avatars
  end

  defimpl Surefire.Game do
    def id(game) do
      game.id
    end

    def enter(game, avatar) do
      Monte.add_player(game)
    end

    def play(game) do
      game
      |> Monte.shuffle()
      |> Monte.stakes()
      |> Monte.reveal()
    end
  end

  # TODO : custom inspect impl to not show card position in IEx...
end
