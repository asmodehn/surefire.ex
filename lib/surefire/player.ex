defprotocol Surefire.Player do
  def id(player)
  def name(player)
  def credits(player)

  #  @type return :: any()
  #  @spec decide(String.t(), %{(String.t() | atom()) => return()}) :: return()
  def decide(player, prompt, choice_map)

  def get(player, gain)
  # or a way to reduce avatars into player ??

  def avatar(player, round)

  def bet(player, bet)
end

defmodule Surefire.TestPlayer do
  alias Surefire.Accounting.Book

  defstruct id: nil,
            ledger: nil,
            avatars: %{},
            avatar_counter: 0,
            action_plan: %{}

  def new(id, initial_assets) do
    %Surefire.TestPlayer{id: id, ledger: Book.new(initial_assets)}
  end

  def with_action(%__MODULE__{} = player, fun_name, fun_body) do
    %{player | action_plan: player.action_plan |> Map.put(:fun_name, fun_body)}
  end

  def avatar(%__MODULE__{} = player, avatar_id_prefix, funds \\ 0) do
    # TODO... WIP

    avatar_id = (avatar_id_prefix <> "#{player.avatar_counter}") |> String.to_atom()
    # create an account for the avatar in players ledger
    avatar_account = Surefire.Accounting.Account.new_debit(avatar_id, "TestAvatar Account")
    updated_ledger = Book.add_external(player.ledger, avatar_account)
    # Shouldnt the Account be mirrored here ??
    avatar = Surefire.Avatar.new(avatar_id, updated_ledger.externals[avatar_id])

    # return the avatar with the account id (as pointer to create a transaction)
    {avatar, %{player | ledger: updated_ledger}}
  end

  # TODO : decorate iex session to show name of player ?
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

    def decide(_player, prompt, choice_map) do
      keys = Map.keys(choice_map)
      choice_idx = Enum.random(0..(length(keys) - 1))
      # pick the answer
      choice_map[Enum.at(keys, choice_idx)]
    end

    def bet(player, bet) do
      #      IO.puts("#{player}/You bet #{bet}")  -> IO monad param in protocol ?
      %{player | credits: player.credits - bet}
    end

    def get(player, gain) do
      #      IO.puts("#{player}/You get #{gain}") -> IO monad param in protocol ?
      %{player | credits: player.credits + gain}
    end
  end

  defimpl String.Chars do
    def to_string(player), do: player.name
  end
end

defmodule Surefire.IExPlayer do
  alias Surefire.Accounting.LedgerServer

  # TODO : isnt the id implicit here (ie. from context : iex, node, etc...)
  defstruct id: nil,
            ledger: nil,
            avatars: %{},
            avatar_counter: 0

  # TODO : only one player per iex session -> HOW ??
  def new(id, funds \\ 0) do
    {:ok, ledger_pid} = GenServer.start_link(LedgerServer, Surefire.Accounting.LogServer)

    :ok = LedgerServer.open_account(ledger_pid, :liabilities, "External Liabilities", :credit)
    :ok = LedgerServer.open_account(ledger_pid, :assets, "Assets", :debit)

    LedgerServer.transfer(ledger_pid, :liabilities, :assets, funds)

    %__MODULE__{
      id: id,
      ledger: ledger_pid
    }
  end

  def new() do
    name = ExPrompt.string_required("What is your name ? ")

    {credits, ""} =
      ExPrompt.string("How much credits do you have? ")
      |> Integer.parse()

    new(name, credits)
  end

  @doc ~s"""
  Avatar is a piece of state, that the player leaves in the game process.

  The avatar is used to interact with the player/user when it cannot make autonomous decisions
  It also can create transactions to update players ledger...

  """
  def avatar(%__MODULE__{ledger: ledger_pid} = player, avatar_id_prefix, funds \\ 0) do
    avatar_id = (avatar_id_prefix <> "#{player.avatar_counter}") |> String.to_atom()
    # TODO : unicity of avatar id !! BEFORE doing transaction...

    # create an account for the avatar in players ledger
    LedgerServer.open_account(ledger_pid, avatar_id, "#{avatar_id} Account", :debit)
    LedgerServer.transfer(ledger_pid, :assets, avatar_id, funds)

    # Currently: # Player -> Avatar
    # LATER: something like (Player Assets -> Avatar )<-> (Game Ledger)

    # the Account is mirrored there (but the ledger is not passed -> no transfer available)
    avatar = Surefire.Avatar.new(avatar_id, LedgerServer.view(ledger_pid, avatar_id))

    # return the avatar with the account id (as pointer to create a transaction)
    # TODO : update avatar in player ? or useless ??
    {avatar, player}
  end

  # TODO : decorate iex session to show name of player ?
  # Note the game being played is hte usual behaviour of function calls in IEx.
  # Only the player interaction requires special handling (communication the "other way".)

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

    #    def avatar(player, round) do
    #      # TODO : avatar_id = player_id-round_id-incr ??
    #      Blackjack.Avatar.IEx.new(player.id |> String.to_atom(), player.id)
    #    end

    def bet(player, bet) do
      IO.puts("#{player}/You bet #{bet}")
      %{player | credits: player.credits - bet}
    end

    def get(player, gain) do
      # TODO : transaction instead !!!!
      %Surefire.IExPlayer{
        player
        | ledger:
            player.ledger
            |> Account.reflect()
      }
    end

    def get(player, gain) do
      IO.puts("#{player}/You get #{gain}")
      %{player | credits: player.credits + gain}
    end
  end

  defimpl String.Chars do
    def to_string(player), do: player.name
  end
end
