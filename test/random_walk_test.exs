defmodule Surefire.RandomWalkTest do
  use ExUnit.Case, async: true

  defmodule StateTest do
    use ExUnit.Case, async: true
    use ExUnitProperties

    alias Surefire.RandomWalk.State

    def range_generator do
      gen all(
            a <- integer(),
            b <- integer()
          ) do
        cond do
          a > b -> b..a//1
          b >= a -> a..b//1
        end
      end
  end

    def state_generator do
      gen all(
            timesteps <- positive_integer(),
            value <- integer(),
            step_range <- range_generator()
          ) do
        %State{timesteps: timesteps, value: value, step_range: step_range}
      end
    end

    #TODO : State is a Category ?
    # => find the set of properties to verify here...

    property "%State{} is initialized to a fixpoint for next/2, except timesteps which is monotonous" do
        check all(step_inc <- positive_integer()) do

      fix = %State{}
      assert fix.timesteps == 0

      assert State.next(fix, step_inc) == %State{fix | timesteps: step_inc}
      end
    end

    property "next/2 allows passing number of steps of 0, which doesn't modify the state" do
      check all(state <- state_generator()) do
        assert State.next(state, 0) == state
      end
    end

    property "next/1 increments by one step" do
      check all(state <- state_generator()) do
        next_state = State.next(state)
        assert next_state.timesteps - state.timesteps == 1
        inc = next_state.value - state.value
        assert inc in state.step_range
      end
    end

  end




end
