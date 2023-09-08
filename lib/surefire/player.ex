defprotocol Surefire.Player do
  def id(player)
  def name(player)
  def credits(player)

  def assets(player)
  def liabilities(player)
  def account(player, account_id)

  #  @type return :: any()
  #  @spec decide(String.t(), %{(String.t() | atom()) => return()}) :: return()
  #  def decide(player, prompt, choice_map)

  def get(player, gain)
  # or a way to reduce avatars into player ??

  def avatar(player, prefix, funds)

  #  def bet(player, bet)
end

defmodule Surefire.TestPlayer do
  alias Surefire.Accounting.LedgerServer
  alias Surefire.Accounting.AccountID

  defstruct id: nil,
            ledger: nil,
            avatars: %{},
            avatar_counter: 0,
            action_plan: %{}

  def new(id, initial_assets) do
    {:ok, ledger_pid} = GenServer.start_link(LedgerServer, Surefire.Accounting.LogServer)

    :ok = LedgerServer.open_account(ledger_pid, :liabilities, "External Liabilities", :credit)
    :ok = LedgerServer.open_account(ledger_pid, :assets, "Assets", :debit)

    LedgerServer.transfer_debit(
      ledger_pid,
      "Financing #{id} assets",
      :liabilities,
      :assets,
      initial_assets
    )

    %__MODULE__{
      id: id,
      ledger: ledger_pid
    }
  end

  def with_action(%__MODULE__{} = player, fun_name, fun_body) do
    %{player | action_plan: player.action_plan |> Map.put(fun_name, fun_body)}
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

    def assets(%Surefire.TestPlayer{ledger: ledger_pid}) do
      %AccountID{ledger_pid: ledger_pid, account_id: :assets}
    end

    def liabilities(%Surefire.TestPlayer{ledger: ledger_pid}) do
      %AccountID{ledger_pid: ledger_pid, account_id: :liabilities}
    end

    def account(%Surefire.TestPlayer{ledger: ledger_pid}, account_id)
        when is_atom(account_id) do
      %AccountID{ledger_pid: ledger_pid, account_id: account_id}
    end

    #
    #    def decide(_player, _prompt, choice_map) do
    #      keys = Map.keys(choice_map)
    #      choice_idx = Enum.random(0..(length(keys) - 1))
    #      # pick the answer
    #      choice_map[Enum.at(keys, choice_idx)]
    #    end

    #    def bet(player, bet) do
    #      #      IO.puts("#{player}/You bet #{bet}")  -> IO monad param in protocol ?
    #      %{player | credits: player.credits - bet}
    #    end

    def avatar(%Surefire.TestPlayer{ledger: ledger_pid} = player, avatar_id_prefix, funds \\ 0) do
      avatar_id = (avatar_id_prefix <> "#{player.avatar_counter}") |> String.to_atom()
      # TODO : unicity of avatar id !! BEFORE doing transaction...

      #    # create an account for the avatar in players ledger
      #    LedgerServer.open_account(ledger_pid, avatar_id, "#{avatar_id} Account", :debit)
      #    LedgerServer.transfer_debit(ledger_pid, "Funding Avatar #{avatar_id}", :assets, avatar_id, funds)

      # Currently: # Player -> Avatar
      # LATER: something like (Player Assets -> Avatar )<-> (Game Ledger)

      # the Account is mirrored there (but the ledger is not passed -> no transfer available)
      avatar = Surefire.Avatar.new(avatar_id, player.id, ledger_pid, avatar_id, funds)

      # return the avatar with the account id (as pointer to create a transaction)
      # TODO : update avatar in player ? or useless ??
      {avatar, player}
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
  alias Surefire.Accounting.AccountID

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

    LedgerServer.transfer_debit(ledger_pid, "Funding #{id} assets", :liabilities, :assets, funds)

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

    def assets(%Surefire.IExPlayer{ledger: ledger_pid}) do
      %AccountID{ledger_pid: ledger_pid, account_id: :assets}
    end

    def liabilities(%Surefire.IExPlayer{ledger: ledger_pid}) do
      %AccountID{ledger_pid: ledger_pid, account_id: :liabilities}
    end

    def account(%Surefire.IExPlayer{ledger: ledger_pid}, account_id)
        when is_atom(account_id) do
      %AccountID{ledger_pid: ledger_pid, account_id: account_id}
    end

    #    def avatar(player, round) do
    #      # TODO : avatar_id = player_id-round_id-incr ??
    #      Blackjack.Avatar.IEx.new(player.id |> String.to_atom(), player.id)
    #    end

    #    def bet(player, bet) do
    #      IO.puts("#{player}/You bet #{bet}")
    #      %{player | credits: player.credits - bet}
    #    end

    @doc ~s"""
    Avatar is a piece of state, that the player leaves in the game process.

    The avatar is used to interact with the player/user when it cannot make autonomous decisions
    It also can create transactions to update players ledger...

    """
    def avatar(%Surefire.IExPlayer{ledger: ledger_pid} = player, avatar_id_prefix, funds \\ 0) do
      avatar_id = (avatar_id_prefix <> "#{player.avatar_counter}") |> String.to_atom()
      # TODO : unicity of avatar id !! BEFORE doing transaction...

      # create an account for the avatar in players ledger
      #    LedgerServer.open_account(ledger_pid, avatar_id, "#{avatar_id} Account", :debit)
      #    LedgerServer.transfer_debit(ledger_pid, "Funding #{avatar_id}", :assets, avatar_id, funds)

      # Currently: # Player -> Avatar
      # LATER: something like (Player Assets -> Avatar )<-> (Game Ledger)

      # we pass the ledger pid and the avatar account id to be able to access it.
      avatar = Surefire.Avatar.new(avatar_id, player.id, ledger_pid, avatar_id, funds)

      # return the avatar with the account id (as pointer to create a transaction)
      # TODO : update avatar in player ? or useless ??
      {avatar, player}
    end

    def get(player, gain) do
      IO.puts("#{player}/You get #{gain}")
      # TODO : transaction !!!!

      player
    end
  end

  defimpl String.Chars do
    def to_string(player), do: player.name
  end
end
