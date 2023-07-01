defmodule Surefire.RandomWalk do
  @moduledoc ~s"""
    A module to simulate a "squared" randomwalk.

    The pace of time is assumed constant, simulated linearly, with a constant variability of a value.
    This can be assumed to be a relative "stable" regime.

    However, overtime there is a probability that the variability itself will change, geometrically.
    These can be thought of as "transition phases" between different stable regimes.

    We hope to simulate here a highly random system overtime,
    without spending too much realtime, and while keeping its "progressive nature".
  """

  defmodule State do
    @moduledoc ~s"""
      A module to store the state of the random walk.
      This bypass simulation of identical step_range, as change can be computed linearly,
      and doesn't require a separate process.
    """
    defstruct timesteps: 0,
              value: 0,
              step_range: 0..0

    def init(step_change \\ -1..1//1) do
      %__MODULE__{step_range: step_change}
    end

    def next(%__MODULE__{} = state, steps \\ 1) do
      # scaling the range to avoid dumb step loop
      # => fast, but internal changes not visible from outside.
      added_value = Enum.random(
        Range.new(
      state.step_range.first*steps,
           state.step_range.last*steps,
                 state.step_range.step
      ))

      %__MODULE__{
        timesteps: state.timesteps + steps,
        value: state.value + added_value,
        step_range: state.step_range
      }
    end

  end

  use GenServer
  ## API

  @type timestep() :: integer()
  @type timestep_increment() :: integer()
  @type value() :: integer()

  @spec ticker(pid(), timestep_increment()) :: {timestep(), value()}
  def ticker(pid, step \\ 1) do
    # TODO : handle timeouts somehow ???
    GenServer.call(pid, {:next, step}) #TODO : better than this, :infinity)
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(value \\  1) do
    {:ok, State.init(-value..value//1)}
  end


  @impl true
  def handle_call({:next, step_increment}, _from, %State{} = state) do

    # TODO: compute potential step_range change

    # TODO: potentially do multiple calls to State.next
    # by slicing timesteps where necessary...
    # Note: the change in "regime" should not be visible from outside...
    # => This will mean that timescale fo calls must be "close enough" to avoid
    # too much random "regime" change -> seems to be what we want...

    updated = State.next(state, step_increment)

    {:reply, {updated.timesteps, updated.value} ,updated}
  end
end
