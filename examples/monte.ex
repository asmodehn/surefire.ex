defmodule Monte.Stake do
  defstruct position: nil, amount: 0

  def new(position, bet_amount) do
    %__MODULE__{
      position: position,
      amount: bet_amount
    }
  end
end

defmodule Monte do
  @moduledoc ~s"""
    # References:
    - https://en.wikipedia.org/wiki/Three-card_Monte

    # Examples
  TODO

  """

  # TODO :  replace this with same cards as blackjack...
  @jclubs :jack_of_clubs
  @jspades :jack_of_spades
  @qhearts :queen_of_hearts

  defstruct id: nil,
            cards: [],
            players: %{},
            stakes: %{},
            wins: %{}

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

  def stakes(%__MODULE__{players: avatars} = game) do
    for {av_id, avatar} <- avatars, reduce: game do
      game_acc -> stake(game_acc, avatar)
    end
  end

  def stake(%__MODULE__{stakes: stakes} = game, %Surefire.Avatar{} = avatar) do
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
      | stakes:
          stakes
          |> Map.put(
            avatar.id,
            %Monte.Stake{position: card_pos, amount: amount}
          )
    }
  end

  def reveal(%__MODULE__{players: avatars} = game) do
    for {av_id, avatar} <- avatars, reduce: game do
      game_acc -> reveal(game_acc, av_id)
    end
  end

  def reveal(%__MODULE__{players: avatars} = game, avatar_id) do
    av_pos = game.stakes[avatar_id].position

    won_amount =
      case game.cards |> Enum.at(av_pos) do
        # lose
        @jclubs ->
          0

        # lose
        @jspades ->
          0

        @qhearts ->
          # win
          game.stakes[avatar_id].amount * 2
      end

    # TODO : gain transaction for winning Avatars
    if won_amount > 0 do
      %{game | wins: game.wins |> Map.put(avatar_id, won_amount)}
    else
      game
    end
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
