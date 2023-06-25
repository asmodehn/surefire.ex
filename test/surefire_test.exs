defmodule SurefireTest do
  use ExUnit.Case
  doctest Surefire

  test "greets the world" do
    assert Surefire.hello() == :world
  end
end
