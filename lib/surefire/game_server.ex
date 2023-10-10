defmodule Surefire.GameServer do
  @moduledoc ~s"""
  `Surefire.GameServer` encapsulate a Game inside a process.
  This way multiple games can be played simultaneously when they are completely automated.

  ## Examples

  iex> m_pid = Surefire.GameServer.start_link(Monte.new(:monte_served), name: :monte_server)
  iex> Surefire.GameServer.enter(m_pid, Surefire.Avatar.new(:mememe))
  iex> result = Surefire.GameServer.play(m_pid)
  """

  # Simply for isolation of multiple parallel games...

  alias Surefire.Game

  use GenServer

  # Client

  def start_link(game_init, opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, game_init, name: name)
  end

  # TODO : enforce fully automated avatar
  # Otherwise interaction happens in the iex process...
  # GOAL: avoid user confusion by preventing concurrent access to iex terminal.
  # TODO : improvement : allow manual avatar if only there is only one per iex terminal.
  # GOAL : multiplayer / multi-iex games
  # when fully_automated(automated)
  def enter(pid, %Surefire.Avatar{automated: %Surefire.Avatar.Automated{} = automated} = avatar) do
    GenServer.cast(pid, {:enter, avatar})
  end

  def play(pid) do
    GenServer.call(pid, :play)
  end

  # Server (callbacks)

  @impl true
  def init(game_init) do
    {:ok, game_init}
  end

  @impl true
  def handle_call({:enter, avatar}, _from, game_state) do
    new_game_state = Game.enter(game_state, avatar)

    {:reply, :ok, new_game_state}
  end

  @impl true
  def handle_call({:play}, game_state) do
    # TODO : play on game to the end.
    #         and return wins & losses

    {:reply, :not_yet_implemented, game_state}
  end
end
